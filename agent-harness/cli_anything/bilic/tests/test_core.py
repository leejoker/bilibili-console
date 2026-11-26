"""Unit tests for cli-anything-bilic.

No network and no real bilic binary: every subprocess boundary is faked.
Covers the backend transport, the text parsers, the locked session file,
the read-only config view, the command envelopes and the Click surface.
"""

import json
import os
import stat
import subprocess
import threading

import pytest
from click.testing import CliRunner

from cli_anything.bilic import bilic_cli
from cli_anything.bilic.core import commands as cmd
from cli_anything.bilic.core import config_view, parsers, session as session_mod
from cli_anything.bilic.utils import bilic_backend

SEP = "-" * 71

SEARCH_TEXT = f"""  av:           114118438687985
  bv:           BV1xx411c7mD
  title:        <em class="keyword">Ruby</em> tutorial &amp; more
  author:       alice
  desc:         first result
  pic:          //i0.hdslb.com/bfs/archive/abc.jpg
  page_size:    3
{SEP}
  av:           42
  bv:           BV1yy411c7mE
  title:        plain title
  author:       bob
  desc:         second result
  pic:          //i0.hdslb.com/bfs/archive/def.jpg
  page_size:    1
{SEP}
"""

FAV_TEXT = f"""  fav_id:         1234
  fav_name:       Music
  media count:    9
{SEP}
"""

FAV_MEDIA_TEXT = f"""  title:         A song
  intro:         intro text
  bv:            BV1aa411c7mF
{SEP}
"""

USER_TEXT = """uid: 42
uname: tester
level: 5
coins: 12
moral: 80
"""

VC_TEXT = f"""sender id:        7
sender name:      alice
sender avatar:    //i0.hdslb.com/avatar.jpg
sender level:     {{:current_level=>4}}
send time:        1700000000

content:          hello there
content_pic:      []

------------------------------------------------------
"""

TREE_TEXT = """bili_console
  ├─ doctor (check environment and third-party dependencies)
  ├─ download_video (download video by bv code)
  ├─ fav_info (show user fav info)
  ├─ login (login with qrcode)
  ├─ manga_checkin (checkin bilibili manga)
  ├─ search (Searching by type)
  ├─ user (get user info)
  └─ vc (Get video comment)
"""


def _completed(stdout="", stderr="", returncode=0):
    return subprocess.CompletedProcess(args=["bilic"], returncode=returncode, stdout=stdout, stderr=stderr)


def _fake_run(monkeypatch, stdout="", stderr="", returncode=0, error=None):
    calls = []

    def runner(argv, **kwargs):
        calls.append({"argv": argv, "kwargs": kwargs})
        if error is not None:
            raise error
        return _completed(stdout=stdout, stderr=stderr, returncode=returncode)

    monkeypatch.setattr(bilic_backend.subprocess, "run", runner)
    monkeypatch.setattr(bilic_backend, "find_bilic", lambda env=None: "/usr/bin/bilic")
    return calls


# ===========================================================================
# 1. find_bilic
# ===========================================================================

class TestFindBilic:
    def test_env_override_is_used(self, tmp_path):
        binary = tmp_path / "bilic"
        binary.write_text("#!/bin/sh\n")
        binary.chmod(binary.stat().st_mode | stat.S_IEXEC)
        assert bilic_backend.find_bilic({"BILIC_BIN": str(binary)}) == str(binary)

    def test_env_override_not_executable_raises(self, tmp_path):
        missing = tmp_path / "nope"
        with pytest.raises(bilic_backend.BilicNotFoundError) as excinfo:
            bilic_backend.find_bilic({"BILIC_BIN": str(missing)})
        assert "BILIC_BIN" in str(excinfo.value)

    def test_path_lookup(self, monkeypatch):
        monkeypatch.setattr(bilic_backend.shutil, "which", lambda name: "/opt/bin/bilic")
        assert bilic_backend.find_bilic({}) == "/opt/bin/bilic"

    def test_missing_binary_mentions_install(self, monkeypatch):
        monkeypatch.setattr(bilic_backend.shutil, "which", lambda name: None)
        with pytest.raises(bilic_backend.BilicNotFoundError) as excinfo:
            bilic_backend.find_bilic({})
        assert "gem install bilibili_console" in str(excinfo.value)


# ===========================================================================
# 2. run_bilic
# ===========================================================================

class TestRunBilic:
    def test_invocation_is_a_list_without_shell(self, monkeypatch):
        calls = _fake_run(monkeypatch, stdout="ok")
        result = bilic_backend.run_bilic(["tree"])
        assert calls[0]["argv"] == ["/usr/bin/bilic", "tree"]
        assert calls[0]["kwargs"]["shell"] is False
        assert calls[0]["kwargs"]["stdin"] is subprocess.DEVNULL
        assert result["ok"] is True

    def test_success_payload(self, monkeypatch):
        _fake_run(monkeypatch, stdout="bili_console\n")
        result = bilic_backend.run_bilic(["tree"])
        assert result["exit_code"] == 0
        assert result["stdout"] == "bili_console\n"
        assert result["error_kind"] is None
        assert result["error"] is None
        assert result["argv"][-1] == "tree"
        assert result["duration_ms"] >= 0

    def test_timeout(self, monkeypatch):
        _fake_run(monkeypatch, error=subprocess.TimeoutExpired(cmd="bilic", timeout=5))
        result = bilic_backend.run_bilic(["login"], timeout=5)
        assert result["ok"] is False
        assert result["error_kind"] == "timeout"
        assert "timed out" in result["error"]

    def test_oserror_means_binary_missing(self, monkeypatch):
        _fake_run(monkeypatch, error=FileNotFoundError("boom"))
        result = bilic_backend.run_bilic(["tree"])
        assert result["error_kind"] == "binary_not_found"
        assert "gem install bilibili_console" in result["error"]

    def test_risk_control_html(self, monkeypatch):
        _fake_run(
            monkeypatch,
            stdout="Error! JSON::ParserError: unexpected character: '<!DOCTYPE'\n",
            stderr="from search.rb:43:in 'Bilibili::Search#search'\n",
            returncode=1,
        )
        result = bilic_backend.run_bilic(["search", "ruby"])
        assert result["error_kind"] == "upstream_response_error"
        assert "non-JSON" in result["error"]

    def test_runtime_error_with_zero_exit_status(self, monkeypatch):
        _fake_run(monkeypatch, stdout="Error! RuntimeError: no cookie\n", returncode=0)
        result = bilic_backend.run_bilic(["user"])
        assert result["ok"] is False
        assert result["error_kind"] == "bilic_error"
        assert "no cookie" in result["error"]

    def test_nonzero_exit(self, monkeypatch):
        _fake_run(monkeypatch, stderr="Could not find command\n", returncode=1)
        result = bilic_backend.run_bilic(["nope"])
        assert result["error_kind"] == "nonzero_exit"
        assert "status 1" in result["error"]

    def test_clean_run_has_no_error(self):
        assert bilic_backend.classify_failure("fine\n", "", 0) == (None, None)


# ===========================================================================
# 3. parsers
# ===========================================================================

class TestParsers:
    def test_field_blocks_split_on_separator(self):
        blocks = parsers.parse_field_blocks(SEARCH_TEXT)
        assert len(blocks) == 2
        assert blocks[0]["bv"] == "BV1xx411c7mD"

    def test_field_blocks_continuation_and_spaced_keys(self):
        text = "media count: 9\nintro: first line\n   second line\n"
        block = parsers.parse_field_blocks(text)[0]
        assert block["media_count"] == 9
        assert "second line" in block["intro"]

    def test_parse_search_coerces_and_strips_tags(self):
        results = parsers.parse_search(SEARCH_TEXT)
        assert len(results) == 2
        assert results[0]["av"] == 114118438687985
        assert results[0]["page_size"] == 3
        assert results[0]["title_plain"] == "Ruby tutorial & more"

    def test_parse_search_empty(self):
        assert parsers.parse_search("") == []

    def test_parse_fav_folders(self):
        parsed = parsers.parse_fav(FAV_TEXT)
        assert len(parsed["folders"]) == 1
        assert parsed["items"] == []
        assert parsed["folders"][0]["media_count"] == 9

    def test_parse_fav_media(self):
        parsed = parsers.parse_fav(FAV_MEDIA_TEXT)
        assert parsed["folders"] == []
        assert parsed["items"][0]["bv"] == "BV1aa411c7mF"

    def test_parse_user_numbers(self):
        user = parsers.parse_user(USER_TEXT)
        assert user["uid"] == 42
        assert user["uname"] == "tester"
        assert user["level"] == 5

    def test_parse_user_empty(self):
        assert parsers.parse_user("") == {}

    def test_parse_vc_comments(self):
        parsed = parsers.parse_vc(VC_TEXT)
        assert parsed["pictures_downloaded"] is False
        assert parsed["comments"][0]["sender_name"] == "alice"
        assert parsed["comments"][0]["content"] == "hello there"

    def test_parse_vc_pictures(self):
        parsed = parsers.parse_vc("Pictures Downloaded\n")
        assert parsed["pictures_downloaded"] is True
        assert parsed["comments"] == []

    def test_parse_manga_checkin_success(self):
        parsed = parsers.parse_manga("签到成功!\n连续签到天数: 7\n")
        assert parsed["message"] == "签到成功!"
        assert parsed["day_count"] == 7
        assert parsed["already_checked_in"] is False

    def test_parse_manga_already(self):
        parsed = parsers.parse_manga("您已经签到了\n")
        assert parsed["already_checked_in"] is True
        assert parsed["day_count"] is None

    def test_parse_manga_info(self):
        parsed = parsers.parse_manga("签到状态: 已签到\n连续签到天数: 3\n")
        assert parsed["status"] == "已签到"
        assert parsed["day_count"] == 3
        assert parsed["already_checked_in"] is True

    def test_parse_tree_aliases(self):
        parsed = parsers.parse_tree(TREE_TEXT)
        assert parsed["root"] == "bili_console"
        assert parsed["count"] == 8
        aliases = {item["name"]: item["cli_name"] for item in parsed["commands"]}
        assert aliases["download_video"] == "down"
        assert aliases["fav_info"] == "fav"
        assert aliases["manga_checkin"] == "manga"
        assert aliases["search"] == "search"

    def test_parse_tree_empty(self):
        parsed = parsers.parse_tree("")
        assert parsed == {"root": None, "commands": [], "count": 0}

    def test_parse_login_urls(self):
        parsed = parsers.parse_login("scan https://passport.bilibili.com/x?a=1 now\n")
        assert parsed["login_urls"] == ["https://passport.bilibili.com/x?a=1"]

    def test_parse_doctor_empty(self):
        assert parsers.parse_doctor("\n") ["output_empty"] is True


# ===========================================================================
# 4. session
# ===========================================================================

class TestSession:
    def test_default_session_shape(self):
        data = session_mod.default_session()
        assert data["version"] == session_mod.SESSION_VERSION
        assert data["defaults"]["qn"] == "720"
        assert data["last_command"] is None
        assert data["last_outputs"] == []

    def test_load_missing_returns_defaults(self, tmp_path):
        assert session_mod.load_session(tmp_path / "absent.json")["last_command"] is None

    def test_load_corrupt_returns_defaults(self, tmp_path):
        broken = tmp_path / "session.json"
        broken.write_text("{not json")
        assert session_mod.load_session(broken) == session_mod.default_session()

    def test_save_load_roundtrip(self, state_dir):
        data = session_mod.default_session()
        data["defaults"]["qn"] = "480"
        path = session_mod.save_session(data)
        assert path == state_dir / "session.json"
        assert session_mod.load_session()["defaults"]["qn"] == "480"

    def test_record_run_sets_last_command(self):
        data = session_mod.default_session()
        session_mod.record_run(data, command="tree", argv=["bilic", "tree"], ok=True, summary={"count": 8})
        assert data["last_command"]["command"] == "tree"
        assert data["last_command"]["ok"] is True
        assert data["last_command"]["summary"] == {"count": 8}
        assert len(data["last_outputs"]) == 1

    def test_record_run_trims_history(self):
        data = session_mod.default_session()
        for index in range(session_mod.OUTPUT_HISTORY_LIMIT + 5):
            session_mod.record_run(data, command=f"c{index}", argv=["bilic"], ok=True)
        assert len(data["last_outputs"]) == session_mod.OUTPUT_HISTORY_LIMIT
        assert data["last_outputs"][-1]["command"] == f"c{session_mod.OUTPUT_HISTORY_LIMIT + 4}"

    def test_reset_session_restores_defaults(self, state_dir):
        data = session_mod.default_session()
        data["defaults"]["qn"] = "1080"
        session_mod.save_session(data)
        reset = session_mod.reset_session()
        assert reset["defaults"]["qn"] == "720"
        assert session_mod.load_session()["defaults"]["qn"] == "720"

    def test_resolve_qn_precedence(self):
        assert session_mod.resolve_qn("480", {"defaults": {"qn": "1080"}}) == "480"
        assert session_mod.resolve_qn(None, {"defaults": {"qn": "1080"}}) == "1080"
        assert session_mod.resolve_qn(None, None) == "720"

    def test_concurrent_saves_stay_parseable(self, state_dir):
        path = state_dir / "session.json"
        session_mod.save_session(session_mod.default_session(), path)
        errors = []

        def worker(index):
            payload = session_mod.default_session()
            payload["defaults"]["qn"] = str(index)
            try:
                session_mod.save_session(payload, path)
            except Exception as exc:  # pragma: no cover - defensive
                errors.append(exc)

        threads = [threading.Thread(target=worker, args=(index,)) for index in range(16)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()

        assert errors == []
        loaded = json.loads(path.read_text())
        assert loaded["defaults"]["qn"] in {str(index) for index in range(16)}


# ===========================================================================
# 5. config view
# ===========================================================================

class TestConfigView:
    def test_missing_config(self, tmp_path):
        view = config_view.config_view(tmp_path / "bilic.conf")
        assert view["exists"] is False
        assert view["content"] is None
        assert view["read_only"] is True

    def test_valid_config(self, tmp_path):
        conf = tmp_path / "bilic.conf"
        conf.write_text('{"proxy": "127.0.0.1:7890", "proxy_type": "http"}')
        view = config_view.config_view(conf)
        assert view["exists"] is True
        assert view["proxy"] == "127.0.0.1:7890"
        assert view["proxy_type"] == "http"
        assert view["parse_error"] is None

    def test_invalid_json_keeps_raw(self, tmp_path):
        conf = tmp_path / "bilic.conf"
        conf.write_text("{broken")
        view = config_view.config_view(conf)
        assert view["raw"] == "{broken"
        assert "not valid JSON" in view["parse_error"]
        assert view["content"] is None


# ===========================================================================
# 6. command envelopes and dry-run semantics
# ===========================================================================

class TestCommands:
    def test_tree_parses_mocked_output(self, monkeypatch):
        _fake_run(monkeypatch, stdout=TREE_TEXT)
        payload = cmd.tree()
        assert payload["ok"] is True
        assert payload["data"]["count"] == 8
        assert payload["upstream"]["argv"][-1] == "tree"
        assert payload["upstream"]["executed"] is True

    def test_doctor_embeds_config(self, monkeypatch, tmp_path):
        conf = tmp_path / "bilic.conf"
        conf.write_text('{"proxy": "127.0.0.1:7890"}')
        monkeypatch.setattr(config_view, "default_config_path", lambda: conf)
        _fake_run(monkeypatch, stdout="")
        payload = cmd.doctor()
        assert payload["ok"] is True
        assert payload["data"]["output_empty"] is True
        assert payload["environment"]["config"]["proxy"] == "127.0.0.1:7890"

    def test_search_parses_results(self, monkeypatch):
        _fake_run(monkeypatch, stdout=SEARCH_TEXT)
        payload = cmd.search("ruby")
        assert payload["ok"] is True
        assert len(payload["data"]["results"]) == 2

    def test_search_failure_envelope(self, monkeypatch):
        _fake_run(monkeypatch, stdout="Error! JSON::ParserError: '<!DOCTYPE'\n", returncode=1)
        payload = cmd.search("ruby")
        assert payload["ok"] is False
        assert payload["error"]["kind"] == "upstream_response_error"
        assert "data" not in payload

    def test_down_dry_run_does_not_execute(self, monkeypatch):
        monkeypatch.setattr(bilic_backend, "find_bilic", lambda env=None: "/usr/bin/bilic")
        monkeypatch.setattr(
            bilic_backend,
            "run_bilic",
            lambda *a, **k: pytest.fail("dry-run must not invoke bilic"),
        )
        payload = cmd.down("BV1xx411c7mD", qn="480", dry_run=True)
        assert payload["dry_run"] is True
        assert payload["upstream"]["executed"] is False
        assert payload["upstream"]["argv"] == ["/usr/bin/bilic", "down", "BV1xx411c7mD", "--qn", "480"]

    def test_down_list_is_read_only_under_dry_run(self, monkeypatch):
        calls = _fake_run(monkeypatch, stdout="file1.flv\n")
        payload = cmd.down("BV1xx411c7mD", list_downloads=True, dry_run=True)
        assert calls, "down --list must still execute"
        assert payload["ok"] is True
        assert payload["data"]["output_lines"] == ["file1.flv"]

    def test_manga_dry_run_blocks_checkin(self, monkeypatch):
        monkeypatch.setattr(bilic_backend, "find_bilic", lambda env=None: "/usr/bin/bilic")
        monkeypatch.setattr(
            bilic_backend, "run_bilic", lambda *a, **k: pytest.fail("dry-run must not check in")
        )
        assert cmd.manga(dry_run=True)["dry_run"] is True

    def test_manga_info_executes_under_dry_run(self, monkeypatch):
        calls = _fake_run(monkeypatch, stdout="签到状态: 未签到\n连续签到天数: 0\n")
        payload = cmd.manga(info=True, dry_run=True)
        assert calls
        assert payload["data"]["status"] == "未签到"

    def test_vc_pic_dry_run_blocks_download(self, monkeypatch):
        monkeypatch.setattr(bilic_backend, "find_bilic", lambda env=None: "/usr/bin/bilic")
        monkeypatch.setattr(
            bilic_backend, "run_bilic", lambda *a, **k: pytest.fail("dry-run must not download")
        )
        assert cmd.vc("123", pic=True, dry_run=True)["dry_run"] is True

    def test_vc_read_only_executes_under_dry_run(self, monkeypatch):
        calls = _fake_run(monkeypatch, stdout=VC_TEXT)
        payload = cmd.vc("123", dry_run=True)
        assert calls
        assert payload["data"]["comments"][0]["sender_id"] == 7

    def test_login_dry_run_never_blocks(self, monkeypatch):
        monkeypatch.setattr(bilic_backend, "find_bilic", lambda env=None: "/usr/bin/bilic")
        monkeypatch.setattr(
            bilic_backend, "run_bilic", lambda *a, **k: pytest.fail("login must not run under --dry-run")
        )
        payload = cmd.login(dry_run=True)
        assert payload["upstream"]["argv"][-1] == "login"

    def test_config_needs_no_bilic(self, monkeypatch, tmp_path):
        conf = tmp_path / "bilic.conf"
        conf.write_text('{"proxy": "127.0.0.1:7890"}')
        monkeypatch.setattr(config_view, "default_config_path", lambda: conf)
        monkeypatch.setattr(bilic_backend, "find_bilic", lambda env=None: pytest.fail("no bilic needed"))
        payload = cmd.config()
        assert payload["data"]["proxy"] == "127.0.0.1:7890"

    def test_user_and_fav(self, monkeypatch):
        _fake_run(monkeypatch, stdout=USER_TEXT)
        assert cmd.user()["data"]["uname"] == "tester"
        _fake_run(monkeypatch, stdout=FAV_TEXT)
        assert len(cmd.fav()["data"]["folders"]) == 1


# ===========================================================================
# 7. CLI surface
# ===========================================================================

class TestCliSurface:
    def _runner(self):
        return CliRunner()

    def test_help_lists_commands(self):
        result = self._runner().invoke(bilic_cli.cli, ["--help"])
        assert result.exit_code == 0
        for name in ("doctor", "tree", "config", "search", "down", "fav", "vc", "manga", "session"):
            assert name in result.output

    def test_json_doctor(self, monkeypatch):
        monkeypatch.setattr(
            cmd, "doctor", lambda dry_run=False: {
                "ok": True,
                "command": "doctor",
                "dry_run": False,
                "upstream": {"binary": "/usr/bin/bilic", "argv": ["/usr/bin/bilic", "doctor"], "exit_code": 0, "executed": True},
                "data": {"output_lines": [], "output_empty": True},
            }
        )
        result = self._runner().invoke(bilic_cli.cli, ["--json", "doctor"])
        assert result.exit_code == 0
        payload = json.loads(result.output)
        assert payload["ok"] is True
        assert payload["upstream"]["exit_code"] == 0

    def test_json_flag_after_subcommand(self, monkeypatch):
        _fake_run(monkeypatch, stdout=TREE_TEXT)
        result = self._runner().invoke(bilic_cli.cli, ["tree", "--json"])
        assert result.exit_code == 0
        assert json.loads(result.output)["data"]["count"] == 8

    def test_config_json(self):
        result = self._runner().invoke(bilic_cli.cli, ["--json", "config"])
        assert result.exit_code == 0
        payload = json.loads(result.output)
        assert payload["data"]["read_only"] is True
        assert payload["data"]["path"].endswith("bilic.conf")

    def test_dry_run_down_writes_no_session(self, monkeypatch, state_dir):
        monkeypatch.setattr(bilic_backend, "find_bilic", lambda env=None: "/usr/bin/bilic")
        monkeypatch.setattr(
            bilic_backend, "run_bilic", lambda *a, **k: pytest.fail("dry-run must not download")
        )
        result = self._runner().invoke(bilic_cli.cli, ["--dry-run", "--json", "down", "BV1"])
        assert result.exit_code == 0
        payload = json.loads(result.output)
        assert payload["dry_run"] is True
        assert payload["upstream"]["executed"] is False
        assert not (state_dir / "session.json").exists()

    def test_failing_command_exits_one(self, monkeypatch):
        _fake_run(monkeypatch, stdout="Error! RuntimeError: no cookie\n", returncode=0)
        result = self._runner().invoke(bilic_cli.cli, ["user"])
        assert result.exit_code == 1
        assert "ERROR [bilic_error]" in result.output

    def test_missing_binary_exits_two(self, monkeypatch):
        monkeypatch.setattr(
            bilic_backend,
            "find_bilic",
            lambda env=None: (_ for _ in ()).throw(bilic_backend.BilicNotFoundError("no bilic here")),
        )
        result = self._runner().invoke(bilic_cli.cli, ["--json", "tree"])
        assert result.exit_code == 2
        assert json.loads(result.output)["error"]["kind"] == "binary_not_found"

    def test_session_show_and_reset(self, state_dir):
        runner = self._runner()
        session_mod.save_session({**session_mod.default_session(), "defaults": {"qn": "1080"}})
        shown = json.loads(runner.invoke(bilic_cli.cli, ["--json", "session", "show"]).output)
        assert shown["data"]["session"]["defaults"]["qn"] == "1080"
        reset = json.loads(runner.invoke(bilic_cli.cli, ["--json", "session", "reset"]).output)
        assert reset["data"]["session"]["defaults"]["qn"] == "720"
        assert json.loads((state_dir / "session.json").read_text())["defaults"]["qn"] == "720"

    def test_unknown_command_fails(self):
        result = self._runner().invoke(bilic_cli.cli, ["nope"])
        assert result.exit_code != 0
