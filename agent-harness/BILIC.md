# BILIC.md - code analysis and harness SOP for bilibili-console

Target: `/data/projects_local/ruby/bilibili-console` (Ruby gem `bilibili_console`,
executable `bilic`), analysed at commit `bbf19df`.
Harness: `agent-harness/cli_anything/bilic/` (package `cli-anything-bilic`).

## 1. Phase 1 - Codebase analysis

### 1.1 What the "application" is

bilibili-console is **not** a GUI application: it is already a CLI. There is no
presentation/engine split to bridge and no document format to manipulate. The
useful analysis is therefore "what is the command surface, what does it print,
and what state does it own".

### 1.2 Layers

| Layer | File | Role |
|-------|------|------|
| Entry point | `bin/bilic` (202 lines) | Thor command definitions, option declarations, `puts` of formatted text |
| Facade | `lib/bilibili_console.rb` | `BilibiliConsole` methods the Thor commands call |
| Domain | `lib/bilibili_console/{video,fav,search,login,manga,video_comment}.rb` | API wrappers that decode each response's `data` into `BiliBliliRecordBase` record objects |
| Transport | `lib/bilibili_console/http/http.rb` | `Net::HTTP` (optionally proxied), cookies, JSON parsing |
| Config | `lib/bilibili_console/config.rb` | Defaults + `~/.bc/bilic.conf` JSON merge |
| Util | `lib/bilibili_console/util/doctor_utils.rb` | Windows-only wget/aria2 checks |

### 1.3 Command surface (verified with `bilic --help` / `bilic tree`)

`bilic tree` prints the CLI names taken from each `desc` (`down`, `play`,
`fav` …) and `bilic help` prints the same names with their arguments
(`down BVID`). The harness still keeps the method-name mapping explicit
(`core/parsers.py:CLI_NAME_ALIASES`) because releases before this one printed
`download_video`/`fav_info`/`manga_checkin` instead.

| Thor method | CLI name | Options | Mutating | Output |
|-------------|----------|---------|----------|--------|
| `config` | `config` | `--json` | no | effective config as `key: value` or JSON |
| `doctor` | `doctor` | – | no | nothing on Linux (see 1.5) |
| `download_video` | `down <bvid>` | `--start`,`--end`,`--page`,`--qn`,`--rename`,`--list`,`--remove`,`--yes`,`--workers` | yes (`--list` read-only) | task summary or downloaded list |
| `fav_info` | `fav` | `--search`,`--fav`,`--page-size`,`--page-num`,`--all` | no | `fav_id/fav_name/media count` or `title/intro/bv` blocks |
| `history` | `history` | `--page`,`--count` | no | `bv/title/author/progress/watched` blocks |
| `login` | `login` | – | yes (writes cookie, blocks on QR scan) | QR code + URL |
| `manga_checkin` | `manga` | `--info` | yes unless `--info` | `签到成功!/连续签到天数` |
| `play` | `play <bvid>` | `--page`,`--qn`,`--player`,`--no-launch` | no (starts a player) | `url/title/part` |
| `saucenao` | `saucenao <target>` | `--db` | no (needs `saucenao_api_key`) | `similarity/index/title/urls` blocks |
| `search` | `search <keyword>` | `--page`,`--bv`,`--av`,`--pic`,`--sort` | `--pic` only | `av/bv/title/author/desc/pic/page_size` blocks |
| `tasks` | `tasks [id]` | `--retry`,`--cancel`,`--remove`,`--yes`,`--workers` | yes | task blocks with segment state |
| `tree` | `tree` | – | no | ASCII command tree (CLI names) |
| `user` | `user` | – | no | `uid/uname/level/coins/moral` |
| `vc` | `vc <bvid>` | `--page`,`--pic` | `--pic` only | `sender id/sender name/…/content` blocks |
| `version` | `version` (`-v`, `--version`) | – | no | `bilic <version>` |

### 1.4 State owned by the target

- `~/.bc/bilic.conf` — JSON merged over `Config::DEFAULT_OPTIONS`
  (`config.rb:19-39`): `proxy`, `proxy_type`, `cookie_json`, `download_dir`,
  `video_pic_dir`, `log_file`, `enable_aria2`, `video_qn`, …
- `~/.bc/cookie.json` — login cookies (`base/base.rb`, also `COOKIE_STR` env)
- `~/.bc/downloads`, `~/.bc/pic`, `~/.bc/tmp` — created by `Config#check_paths`
- `~/.bc/bilic.log` — the Ruby logger

The harness treats all of them as **read-only**: it only ever reads
`~/.bc/bilic.conf` (`core/config_view.py`) and never writes there.

### 1.5 Behaviour that shapes the design

1. **No `--json`.** Every command prints formatted text, so the harness parses
   it (`core/parsers.py`). Fields that are absent in the text stay absent in the
   JSON — the parser never invents values.
2. **Two failure shapes, both exit 1.** Argument errors are printed by Thor
   (`ERROR: "bilic play" was called with no arguments` / the Chinese hint the
   command raises itself). Runtime exceptions go through the `at_exit` hook in
   `bin/bilic`, which prints `Error! <Class>: <message>` + `Please check the error
   log.` Both exit non-zero (`exit_on_failure?` is true) — verified with a dead
   proxy: `rc=1`, `Error! Errno::ECONNREFUSED: …`. The backend still classifies the
   `Error!` line rather than trusting `returncode` alone
   (`utils/bilic_backend.py:classify_failure`).
3. **bilibili's WAF answers with HTML.** The Ruby client parses responses with
   `JSON.parse` (`http/http.rb:187`), so an HTTP 412 risk-control page becomes
   `JSON::ParserError: unexpected character: '<!DOCTYPE'`. Observed on this
   machine for `search` — the harness maps it to
   `error.kind = "upstream_response_error"` instead of pretending there were no
   results.
4. **`doctor` is a no-op off Windows.** `Doctor.check_wget` returns immediately
   unless `windows_command_check` says "missing", and that helper is
   Windows-only (`doctor_utils.rb:93-101`); `check_aria2` is only called when
   `enable_aria2` is set. So `bilic doctor` prints nothing and exits 0 on Linux.
   The harness reports an empty result as the truth and attaches the real config
   snapshot so the command is still useful.
5. **`down --list` reads the download dir, nothing more.** It prints one block per
   subdirectory of `download_dir` (bv/title/files/size/path) and never touches the
   network, so the harness treats it as read-only.
6. **`login` blocks** on a QR scan and writes `~/.bc/cookie.json`. The harness
   never runs it in tests, exposes `--timeout`, and `--dry-run` short-circuits it.
7. **`search` fans out.** `Search#get_pages` calls `video_page_list` once per
   result (`search.rb:79`), so one harness `search` is ~20 upstream requests.
   That is why the harness keeps a 300 s timeout and why the E2E suite treats a
   single search as the whole network budget.
8. **`play` needs a Referer.** The CDN URL from `playurl` answers `403` to a plain
   GET (measured: 471-byte edge error), and `200` once `Referer:
   https://www.bilibili.com/` is sent. `Bilibili::LocalPlayer` injects that header
   for mpv (`--http-header-fields=Referer: …`) and vlc (`--http-referrer=…`);
   anything else (`xdg-open`, a bare player path) only receives the URL and will
   fail. `--no-launch` exists precisely so a caller can fetch with its own
   headers.

### 1.6 Environment facts (verified, this machine)

- `bilic` → `/home/boe/.local/share/mise/installs/ruby/latest/bin/bilic`
  (the gem-installed 0.0.3 copy of `bin/bilic`).
- `~/.bc/bilic.conf` = `{"proxy": "127.0.0.1:7890", "proxy_type": "http"}`.
- Direct `https://api.bilibili.com` from this host fails (reset); through the
  HTTP proxy the same URL answers (HTTP 200 JSON, occasionally 412).

## 2. Phase 2 - CLI architecture

### 2.1 Interaction model

Both modes, unified:

- one-shot subcommands (`tree`, `doctor`, `config`, `search`, `down`, `fav`,
  `vc`, `manga`, `user`, `login`, `session`), each with `--json`;
- REPL as the default when no subcommand is given
  (`invoke_without_command=True` → `_repl_loop()` → `ReplSkin`).

### 2.2 Layering

```
bilic_cli.py  (Click surface, rendering, session auto-save, REPL)
   └── core/commands.py     (argv builders, envelopes, dry-run gates)
          ├── utils/bilic_backend.py   (the only subprocess boundary)
          ├── core/parsers.py          (bilic text -> structured data)
          ├── core/config_view.py      (read-only ~/.bc/bilic.conf)
          └── core/session.py          (locked harness state)
```

The single non-negotiable rule: **no bilibili HTTP in Python.** Everything the
harness reports about bilibili comes from a real `bilic` invocation.

### 2.3 JSON envelope

```json
{"ok": true, "command": "search", "dry_run": false,
 "upstream": {"binary": "…", "argv": ["…","search","ruby"], "exit_code": 0,
              "executed": true, "duration_ms": 1807, "stdout_bytes": 28306,
              "stderr_tail": ""},
 "data": {"results": []}}
```

Errors replace `data` with `error: {kind, message, stdout_excerpt}`. The
`upstream` block is the audit trail that proves which binary ran with which
argv — that is what makes the wrapper verifiable rather than speculative.

### 2.4 Dry-run

Mutating commands are gated *before* `run_bilic` (`core/commands.py:_execute`).
The reported argv is the exact list that would have been executed, resolved
through the same `find_bilic()` the real path uses. Nothing is written to the
session file.

### 2.5 Session

`~/.config/cli-anything-bilic/session.json` (override:
`CLI_ANYTHING_BILIC_STATE_DIR`), written with `_locked_save_json`
(`open("r+")` → `flock(LOCK_EX)` → `seek/truncate` inside the lock). Contents:
`last_command`, `last_outputs` (20 newest), `defaults.qn`.

Auto-save runs immediately after each invocation `_finalize`, and a
`result_callback` safety net saves anything still dirty on the way out; the
guide's "never lose a one-shot mutation" requirement is therefore satisfied for
success *and* failure paths. `--dry-run` suppresses both execution (for
mutating commands) and every write.

## 3. Phase 3-7 - what was built

| Phase | Deliverable |
|-------|-------------|
| 3 Implementation | `bilic_cli.py`, `core/{commands,parsers,session,config_view}.py`, `utils/bilic_backend.py`, `utils/repl_skin.py` (copied verbatim from the plugin) |
| 4 Test planning | `cli_anything/bilic/tests/TEST.md` written before any test code |
| 5 Test implementation | `test_core.py` (63 unit tests, subprocess mocked) and `test_full_e2e.py` (19 tests against real `bilic` + installed console script, no skips) |
| 6 Test documentation | results appended to `TEST.md` |
| 6.5 Skill | `skills/cli-anything-bilic/SKILL.md` (canonical) + packaged copy `cli_anything/bilic/skills/SKILL.md` |
| 7 Publishing | `setup.py` with `find_namespace_packages(include=["cli_anything.*"])`, `console_scripts` entry, `package_data` for `skills/*.md`; `cli_anything/` has **no** `__init__.py` |

## 4. Deliberate deviations, and why

1. **No `preview` command group.** There is no local project state to render and
   no offscreen export path; a preview bundle would have to be fabricated or
   screen-scraped, which violates the truthfulness principle. Stated in
   `README.md` and `SKILL.md` as required.
2. **`--dry-run` on mutating commands does not execute.** The generic guide says
   "command executes, output printed, project not saved". Here the mutation is a
   real download or a remote account change, so executing it would defeat the
   purpose of a rehearsal. Read-only commands keep the literal guide semantics.
3. **`doctor` reports an empty payload as success.** That is the target's real
   behaviour on Linux (1.5.4); the payload says so explicitly instead of
   pretending a check ran.
4. **No `--project` flag.** bilic has no project file; the harness session is
   the only persistent state, keyed to a single state directory.

## 5. Drift watch list

- If bilic starts emitting `Error!` with a different prefix, or stops exiting 0
  on failure, revisit `classify_failure`.
- If `Config#DEFAULT_OPTIONS` gains a different default `video_qn`,
  `session.FALLBACK_QN` (currently `"720"`, matching `bin/bilic:84`) must follow.
- If a `--json` flag is ever added upstream, replace `core/parsers.py` with the
  native payload and keep the same envelope.
