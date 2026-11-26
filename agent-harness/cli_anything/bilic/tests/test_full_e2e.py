"""End-to-end tests for cli-anything-bilic against the REAL bilic executable.

Nothing is skipped here. If the `bilic` binary is missing the tests fail with
the install instructions; if the real network path is blocked the search test
still fails when the harness fails to report that honestly.

The only network traffic produced by this module is one `bilic search`
(plus one retry when bilibili answers with its risk-control page); everything
else is local `bilic tree`/`bilic doctor` execution.
"""

import json
import os
import shutil
import subprocess
import sys
import time

import pytest

from cli_anything.bilic.utils import bilic_backend


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _resolve_cli(name):
    """Resolve the installed cli-anything command, falling back to python -m.

    Set CLI_ANYTHING_FORCE_INSTALLED=1 to require the installed command.
    """
    force = os.environ.get("CLI_ANYTHING_FORCE_INSTALLED", "").strip() == "1"
    path = shutil.which(name)
    if path:
        print(f"[_resolve_cli] Using installed command: {path}")
        return [path]
    if force:
        raise RuntimeError(f"{name} not found in PATH. Install with: pip install -e .")
    module = "cli_anything.bilic.bilic_cli"
    print(f"[_resolve_cli] Falling back to: {sys.executable} -m {module}")
    return [sys.executable, "-m", module]


def _run_cli(*args, timeout=180, stdin_text=None):
    return subprocess.run(
        _resolve_cli("cli-anything-bilic") + list(args),
        capture_output=True,
        text=True,
        timeout=timeout,
        input=stdin_text,
    )


def _require_bilic():
    try:
        return bilic_backend.find_bilic()
    except bilic_backend.BilicNotFoundError as exc:
        pytest.fail(f"bilic is a hard dependency of this harness: {exc}")


# ---------------------------------------------------------------------------
# Real backend
# ---------------------------------------------------------------------------

class TestRealBilicBackend:
    def test_binary_resolves_to_an_executable(self):
        binary = _require_bilic()
        assert os.path.isfile(binary)
        assert os.access(binary, os.X_OK)
        print(f"\n  bilic: {binary}")

    def test_real_tree_invocation(self):
        _require_bilic()
        result = bilic_backend.run_bilic(["tree"], timeout=120)
        assert result["ok"] is True, result["error"]
        assert result["exit_code"] == 0
        assert "bili_console" in result["stdout"]
        assert result["argv"][0].endswith("bilic")

    def test_real_doctor_invocation(self):
        _require_bilic()
        result = bilic_backend.run_bilic(["doctor"], timeout=120)
        assert result["ok"] is True, result["error"]
        assert result["exit_code"] == 0
        print(f"\n  doctor stdout: {result['stdout']!r} (no-op off Windows)")


# ---------------------------------------------------------------------------
# Real search over the configured proxy (one network call, one retry)
# ---------------------------------------------------------------------------

class TestRealSearchE2E:
    def test_search_reports_real_network_outcome(self):
        """A real `search` must either parse bilibili data or report the block.

        ~/.bc/bilic.conf routes bilic through the configured proxy; direct
        access to bilibili is reset from this machine, so this call is the only
        proof the whole chain works. bilibili intermittently answers with an
        HTTP 412 risk-control page, which makes bilic die in JSON.parse - the
        harness must surface that as a structured error, never as silence.
        """
        _require_bilic()
        payload = None
        result = None
        attempts = []
        for attempt in range(2):
            result = _run_cli("--json", "search", "ruby", timeout=240)
            attempts.append(result.returncode)
            payload = json.loads(result.stdout)
            if payload.get("ok"):
                break
            time.sleep(3)

        upstream = payload["upstream"]
        assert upstream["executed"] is True
        assert "search" in upstream["argv"]
        assert upstream["binary"].endswith("bilic")
        assert upstream["stdout_bytes"] > 0 or upstream["stderr_tail"]
        print(f"\n  search attempts: {attempts} -> ok={payload['ok']}")

        if payload["ok"]:
            results = payload["data"]["results"]
            assert results, "ok payload must carry parsed results"
            first = results[0]
            assert first["bv"], "every parsed result carries a bv id"
            assert "title_plain" in first
            print(f"  first result: {first['bv']} {first['title_plain'][:60]!r}")
        else:
            error = payload["error"]
            assert error["kind"] in {"upstream_response_error", "nonzero_exit"}, error
            assert error["message"].strip()
            print(
                "\n  bilibili blocked the search request (documented in TEST.md): "
                f"{error['kind']} - {error['message'][:120]}"
            )


# ---------------------------------------------------------------------------
# Tree, REPL, help, config
# ---------------------------------------------------------------------------

class TestTreeE2E:
    def test_tree_json_is_parsed(self):
        result = _run_cli("--json", "tree")
        assert result.returncode == 0, result.stderr
        payload = json.loads(result.stdout)
        assert payload["ok"] is True
        data = payload["data"]
        assert data["root"] == "bili_console"
        assert data["count"] >= 8
        names = {item["cli_name"] for item in data["commands"]}
        assert {"doctor", "down", "fav", "login", "manga", "search", "user", "vc"} <= names
        print(f"\n  parsed {data['count']} commands: {sorted(names)}")

    def test_tree_human(self):
        result = _run_cli("tree")
        assert result.returncode == 0
        assert "bili_console" in result.stdout


class TestReplE2E:
    def test_repl_exits_cleanly_on_eof(self):
        result = _run_cli(stdin_text="")
        assert result.returncode == 0, result.stderr
        assert "cli-anything" in result.stdout
        assert "Goodbye" in result.stdout
        print("\n  REPL entered and exited on EOF")

    def test_repl_runs_a_piped_command(self):
        result = _run_cli(stdin_text="tree --json\nquit\n")
        assert result.returncode == 0, result.stderr
        assert "bili_console" in result.stdout
        assert "Goodbye" in result.stdout


class TestHelpE2E:
    def test_help(self):
        result = _run_cli("--help")
        assert result.returncode == 0
        assert "Usage:" in result.stdout
        assert "Commands:" in result.stdout

    def test_version(self):
        result = _run_cli("--version")
        assert result.returncode == 0
        assert "1.0.0" in result.stdout


class TestConfigE2E:
    def test_config_is_read_only_and_reports_proxy(self):
        result = _run_cli("--json", "config")
        assert result.returncode == 0, result.stderr
        data = json.loads(result.stdout)["data"]
        assert data["path"].endswith(".bc/bilic.conf")
        assert data["read_only"] is True
        assert data["exists"] is True
        assert data["proxy"], "bilic.conf must configure the proxy this machine needs"
        print(f"\n  config: {data['path']} proxy={data['proxy']} type={data['proxy_type']}")


# ---------------------------------------------------------------------------
# Installed CLI subprocess tests
# ---------------------------------------------------------------------------

class TestCLISubprocess:
    CLI_BASE = _resolve_cli("cli-anything-bilic")

    def _run(self, args, timeout=180, stdin_text=None):
        return subprocess.run(
            self.CLI_BASE + args,
            capture_output=True,
            text=True,
            timeout=timeout,
            input=stdin_text,
        )

    def test_help(self):
        result = self._run(["--help"])
        assert result.returncode == 0

    def test_doctor_json(self):
        result = self._run(["--json", "doctor"])
        assert result.returncode == 0, result.stderr
        payload = json.loads(result.stdout)
        assert payload["ok"] is True
        upstream = payload["upstream"]
        assert upstream["executed"] is True
        assert upstream["exit_code"] == 0
        assert os.path.isfile(upstream["binary"])
        assert payload["environment"]["config"]["path"].endswith("bilic.conf")

    def test_tree_json(self):
        result = self._run(["tree", "--json"])
        assert result.returncode == 0, result.stderr
        payload = json.loads(result.stdout)
        assert payload["data"]["root"] == "bili_console"

    def test_config_json(self):
        result = self._run(["--json", "config"])
        assert result.returncode == 0, result.stderr
        assert json.loads(result.stdout)["data"]["read_only"] is True

    def test_down_dry_run_does_not_download(self):
        download_dir = os.path.expanduser("~/.bc/downloads")
        before = sorted(os.listdir(download_dir)) if os.path.isdir(download_dir) else []
        result = self._run(["--dry-run", "--json", "down", "BV1xx411c7mD", "--qn", "480"])
        assert result.returncode == 0, result.stderr
        payload = json.loads(result.stdout)
        assert payload["dry_run"] is True
        assert payload["upstream"]["executed"] is False
        assert payload["upstream"]["argv"][-2:] == ["--qn", "480"]
        after = sorted(os.listdir(download_dir)) if os.path.isdir(download_dir) else []
        assert before == after, "dry-run must not write into the download directory"

    def test_session_show_json(self):
        result = self._run(["--json", "session", "show"])
        assert result.returncode == 0, result.stderr
        data = json.loads(result.stdout)["data"]
        assert data["path"].endswith("session.json")
        assert "defaults" in data["session"]

    def test_version(self):
        result = self._run(["--version"])
        assert result.returncode == 0
        assert "1.0.0" in result.stdout

    def test_unknown_subcommand_fails(self):
        result = self._run(["definitely-not-a-command"])
        assert result.returncode != 0
