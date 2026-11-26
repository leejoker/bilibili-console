# TEST.md - cli-anything-bilic test plan and results

Software under test: `bilic` (bilibili-console, a Ruby/Thor CLI) driven through
`cli-anything-bilic`. The harness adds no HTTP of its own: every bilibili
interaction is a subprocess call to the real `bilic` executable.

## Test Inventory Plan

| File | Scope | Planned tests |
|------|-------|---------------|
| `test_core.py` | Unit tests, no network, no real `bilic` (subprocess mocked) | 49 |
| `test_full_e2e.py` | Real `bilic` invocations + installed CLI subprocess | 26 |

Total planned: 75 tests.

## Unit Test Plan (`test_core.py`)

### 1. `utils/bilic_backend.py` - binary discovery (4 tests)

`find_bilic()`

- returns `$BILIC_BIN` when it points at an executable file
- raises `BilicNotFoundError` when `$BILIC_BIN` is not executable (message names the variable)
- returns the PATH hit from `shutil.which`
- raises `BilicNotFoundError` with install instructions when nothing is found

### 2. `utils/bilic_backend.py` - `run_bilic()` (7 tests)

- argv is a list, `shell=False`, stdin is not inherited
- success result carries exit_code 0, stdout, `ok=True`, `error_kind=None`
- `subprocess.TimeoutExpired` maps to `error_kind="timeout"`
- `OSError` maps to `error_kind="binary_not_found"`
- `Error! JSON::ParserError` + `<!DOCTYPE` maps to `upstream_response_error`
- `Error! RuntimeError: ...` on an exit-0 process maps to `bilic_error` (bilic hides
  status in its `at_exit` handler, so the exit code alone is not trustworthy)
- real non-zero exit maps to `nonzero_exit`

### 3. `core/parsers.py` - text -> structure (14 tests)

- `parse_field_blocks`: key/value blocks, dash separators, multi-line continuation,
  keys containing spaces, numeric coercion
- `parse_search`: two blocks -> two dicts, `av`/`page_size` as ints,
  `<em class="keyword">` stripped into `title_plain`, empty input -> `[]`
- `parse_fav`: folder blocks vs media blocks are classified separately
- `parse_user`: uid/uname/level/coins/moral with numeric coercion
- `parse_vc`: comment blocks; `Pictures Downloaded` short-circuit
- `parse_manga`: check-in success, "already checked in", and `--info` status
- `parse_tree`: root + one-level Thor tree, `cli_name` aliasing
  (`download_video`->`down`, `fav_info`->`fav`), empty input
- `parse_login`: URL extraction
- `parse_doctor`: empty output is reported as empty (not as failure)

### 4. `core/session.py` - state + locking (8 tests)

- `default_session()` shape (version, defaults.qn="720", no last command)
- missing file -> defaults; corrupt JSON -> defaults (never an exception)
- save/load round-trip through `CLI_ANYTHING_BILIC_STATE_DIR`
- `record_run()` sets `last_command` and appends to `last_outputs`
- `last_outputs` respects `OUTPUT_HISTORY_LIMIT`
- `reset_session()` restores defaults on disk
- `resolve_qn()` precedence: explicit flag > session default > "720"
- concurrent writers (16 threads) leave a parseable session file - the
  `_locked_save_json` (`r+` + flock + truncate-inside-lock) contract

### 5. `core/config_view.py` (3 tests)

- missing config -> `exists=False`, no exception
- valid JSON config -> parsed content, proxy and proxy_type surfaced
- invalid JSON -> `parse_error` set, raw text still returned

### 6. `core/commands.py` - envelope + dry-run semantics (9 tests)

- `tree` and `doctor` succeed against a mocked backend; `doctor` embeds the config view
- `search` parses results; a backend failure becomes `ok=False` + `error.kind`
- `down --dry-run` never calls the backend and reports the exact argv
- `down --list --dry-run` still executes (read-only)
- `manga --dry-run` does not execute; `manga --info --dry-run` does
- `vc --pic --dry-run` does not execute; `vc --dry-run` does
- `login --dry-run` does not execute (never blocks)
- `config` works without invoking `bilic` at all

### 7. `bilic_cli.py` - CLI surface (8 tests, Click `CliRunner`)

- `--help` exits 0 and lists every command
- `--json doctor` emits parseable JSON with real upstream metadata shape
- `tree --json` (flag after the subcommand) is honoured as well
- `config --json` reports path/read_only
- `--dry-run down ... --json` reports `executed: false` and writes no session file
- a failing backend exits 1 and prints `ERROR [...]` in human mode
- a missing `bilic` exits 2 with `error.kind == "binary_not_found"`
- `session show` / `session reset` round-trip through the isolated state dir

## E2E Test Plan (`test_full_e2e.py`)

**No graceful degradation:** if `bilic` (or its network path) is unusable the
E2E tests fail, they never skip.

### Real backend (`TestRealBilicBackend`, 3 tests)

- `find_bilic()` returns an executable path
- `run_bilic(["tree"])` exits 0 and prints the `bili_console` tree
- `run_bilic(["doctor"])` exits 0 (doctor is a no-op off Windows - that is the
  real behaviour, recorded as such)

### Real search over the configured proxy (`TestRealSearchE2E`, 2 tests)

`~/.bc/bilic.conf` sets `proxy: 127.0.0.1:7890`; direct bilibili access is reset
from this machine, so a successful `search` proves the proxy path works.

- **workflow**: `cli-anything-bilic --json search ruby` (one real invocation, one
  retry if bilibili answers with a non-JSON risk-control page)
- **verified**: stdout is parseable JSON; `upstream.executed` is true and
  `upstream.argv` contains `search`; either
  (a) `ok: true` with at least one parsed result carrying `bv`/`title_plain`, or
  (b) `ok: false` with `error.kind` in {`upstream_response_error`, `nonzero_exit`}
  and a message naming the non-JSON response - the truthful report of a bilibili
  WAF block (observed during development: HTTP 412 / `JSON::ParserError`),
  never a silent pass
- second test asserts the human (non-JSON) path exits with a status consistent
  with the payload (0 on results, 1 on an upstream block)

### Introspection + REPL (`TestTreeAndReplE2E`, 4 tests)

- `tree --json` returns the parsed tree: root `bili_console`, all 8 Thor
  commands, `download_video`/`fav_info`/`manga_checkin` aliased to
  `down`/`fav`/`manga`
- `tree` (human) exits 0 and mentions the root
- no arguments enters the REPL and exits cleanly on EOF (exit code 0, banner and
  goodbye present)
- the REPL executes a piped command (`tree\nquit\n`) and still exits 0

### Installed CLI subprocess (`TestCLISubprocess`, 8 tests)

Uses `_resolve_cli("cli-anything-bilic")`; with `CLI_ANYTHING_FORCE_INSTALLED=1`
the tests fail (not skip) when the console script is missing.

- `--help` exits 0
- `--json doctor` parses and reports the real binary path/exit code
- `tree --json` parses
- `config --json` reports the real `~/.bc/bilic.conf` path (read-only)
- `down BV... --dry-run --json` reports `executed: false` (no download happens)
- `session show --json` reports the isolated session path
- `--version` prints the harness version
- an unknown subcommand exits non-zero

### Realistic workflow scenario

**Name:** investigate before touching an account
**Simulates:** an agent that must learn the target CLI's surface, its
environment, and its data before running anything destructive.
**Operations chained:** `tree --json` -> `doctor --json` -> `config --json` ->
`search --json` -> `session show --json` -> `down <id> --dry-run --json`.
**Verified:** each step emits parseable JSON, the only network step is `search`,
`down` never executes, and the session file records what ran.

## Results

Run command (from `agent-harness/`):

```bash
CLI_ANYTHING_FORCE_INSTALLED=1 python3 -m pytest cli_anything/bilic/tests -v --tb=short
```

```text
82 passed in 14.77s
```

### Summary statistics

| Metric | Value |
|--------|-------|
| Total tests | 82 |
| `test_core.py` (unit, subprocess mocked) | 63 |
| `test_full_e2e.py` (real `bilic` + installed CLI) | 19 |
| Pass rate | 100% |
| Wall clock | 14.77s |
| Network calls made by the suite | 1 real `bilic search` (+1 retry if bilibili risk-controls it) |

Plan vs. delivery: the plan estimated 49 unit + 26 E2E; the delivered split is 63 + 19.
Two planned E2E tests were merged into one: the search test now covers both the
JSON payload and the honest failure path, because a second network search would
have doubled traffic for the same assertion. Human-mode search rendering is
covered offline by `TestCliSurface::test_failing_command_exits_one` and
`TestCliSurface::test_json_flag_after_subcommand`. A few unit-test cases were
split out while writing them (field-block continuation, empty user/doctor input,
binary resolution), which is where the extra unit tests come from.

### Environment observed while running the suite

```text
bilic            /home/boe/.local/share/mise/installs/ruby/latest/bin/bilic
bilic.conf       ~/.bc/bilic.conf  ->  {"proxy": "127.0.0.1:7890", "proxy_type": "http"}
direct bilibili  https://api.bilibili.com        -> connection reset (expected)
through proxy    https://api.bilibili.com/...    -> HTTP 200 JSON, sometimes HTTP 412 HTML
installed CLI    /home/boe/.local/bin/cli-anything-bilic  (pip install -e . --user)
```

### Real `search` result

`search` was executed for real through the configured proxy. bilibili's WAF
answers with an HTML risk-control page for bilic's bundled User-Agent
(Chrome/91) often enough that the Ruby client dies in `JSON.parse`:

```text
Error! JSON::ParserError: unexpected character: '<!DOCTYPE' at line 1 column 1
```

The harness reports that honestly as `ok: false, error.kind:
"upstream_response_error"` (with `upstream.executed: true` and the real
`bilic` argv) instead of an empty result list. When bilibili does answer with
JSON, the same test asserts the parsed results carry `bv`/`title_plain`/
`page_size`. The test fails if the harness ever reports silence, a fabricated
result, or an invocation that did not happen.

### Coverage notes and gaps

- **Not exercised against live bilibili on purpose:** `user`, `fav`, `vc`,
  `manga` (mutating), `down` (mutating) and `login`. `login` blocks on a QR
  scan and the rest write to the account or to `~/.bc/`. They are covered by
  unit tests (mocked backend), by `--dry-run` argv tests, and by the
  `down --dry-run` subprocess test that also asserts `~/.bc/downloads` is
  unchanged.
- **No preview surface** (documented in README.md/SKILL.md): bilic owns no
  local renderable state, so there is nothing truthful to capture.
- **Parsers are text-scraping by necessity** - bilic has no `--json`. If the
  target's `puts` blocks change, `core/parsers.py` must change with them; the
  unit tests pin the current format.
- **`down --list` is a declared-but-unused option upstream** (BILIC.md
  section 1.5.5); the harness passes it through and invents no behaviour for it.
- **`doctor` prints nothing on Linux** and is verified as an empty-but-ok
  payload (BILIC.md section 1.5.4).

### Full output

```text
============================= test session starts ==============================
platform linux -- Python 3.14.4, pytest-9.2.0, pluggy-1.7.0 -- /usr/bin/python3
cachedir: .pytest_cache
rootdir: /data/projects_local/ruby/bilibili-console/agent-harness
plugins: typeguard-4.4.4
collecting ... collected 82 items

cli_anything/bilic/tests/test_core.py::TestFindBilic::test_env_override_is_used PASSED [  1%]
cli_anything/bilic/tests/test_core.py::TestFindBilic::test_env_override_not_executable_raises PASSED [  2%]
cli_anything/bilic/tests/test_core.py::TestFindBilic::test_path_lookup PASSED [  3%]
cli_anything/bilic/tests/test_core.py::TestFindBilic::test_missing_binary_mentions_install PASSED [  4%]
cli_anything/bilic/tests/test_core.py::TestRunBilic::test_invocation_is_a_list_without_shell PASSED [  6%]
cli_anything/bilic/tests/test_core.py::TestRunBilic::test_success_payload PASSED [  7%]
cli_anything/bilic/tests/test_core.py::TestRunBilic::test_timeout PASSED [  8%]
cli_anything/bilic/tests/test_core.py::TestRunBilic::test_oserror_means_binary_missing PASSED [  9%]
cli_anything/bilic/tests/test_core.py::TestRunBilic::test_risk_control_html PASSED [ 10%]
cli_anything/bilic/tests/test_core.py::TestRunBilic::test_runtime_error_with_zero_exit_status PASSED [ 12%]
cli_anything/bilic/tests/test_core.py::TestRunBilic::test_nonzero_exit PASSED [ 13%]
cli_anything/bilic/tests/test_core.py::TestRunBilic::test_clean_run_has_no_error PASSED [ 14%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_field_blocks_split_on_separator PASSED [ 15%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_field_blocks_continuation_and_spaced_keys PASSED [ 17%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_search_coerces_and_strips_tags PASSED [ 18%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_search_empty PASSED [ 19%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_fav_folders PASSED [ 20%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_fav_media PASSED [ 21%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_user_numbers PASSED [ 23%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_user_empty PASSED [ 24%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_vc_comments PASSED [ 25%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_vc_pictures PASSED [ 26%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_manga_checkin_success PASSED [ 28%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_manga_already PASSED [ 29%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_manga_info PASSED [ 30%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_tree_aliases PASSED [ 31%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_tree_empty PASSED [ 32%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_login_urls PASSED [ 34%]
cli_anything/bilic/tests/test_core.py::TestParsers::test_parse_doctor_empty PASSED [ 35%]
cli_anything/bilic/tests/test_core.py::TestSession::test_default_session_shape PASSED [ 36%]
cli_anything/bilic/tests/test_core.py::TestSession::test_load_missing_returns_defaults PASSED [ 37%]
cli_anything/bilic/tests/test_core.py::TestSession::test_load_corrupt_returns_defaults PASSED [ 39%]
cli_anything/bilic/tests/test_core.py::TestSession::test_save_load_roundtrip PASSED [ 40%]
cli_anything/bilic/tests/test_core.py::TestSession::test_record_run_sets_last_command PASSED [ 41%]
cli_anything/bilic/tests/test_core.py::TestSession::test_record_run_trims_history PASSED [ 42%]
cli_anything/bilic/tests/test_core.py::TestSession::test_reset_session_restores_defaults PASSED [ 43%]
cli_anything/bilic/tests/test_core.py::TestSession::test_resolve_qn_precedence PASSED [ 45%]
cli_anything/bilic/tests/test_core.py::TestSession::test_concurrent_saves_stay_parseable PASSED [ 46%]
cli_anything/bilic/tests/test_core.py::TestConfigView::test_missing_config PASSED [ 47%]
cli_anything/bilic/tests/test_core.py::TestConfigView::test_valid_config PASSED [ 48%]
cli_anything/bilic/tests/test_core.py::TestConfigView::test_invalid_json_keeps_raw PASSED [ 50%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_tree_parses_mocked_output PASSED [ 51%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_doctor_embeds_config PASSED [ 52%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_search_parses_results PASSED [ 53%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_search_failure_envelope PASSED [ 54%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_down_dry_run_does_not_execute PASSED [ 56%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_down_list_is_read_only_under_dry_run PASSED [ 57%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_manga_dry_run_blocks_checkin PASSED [ 58%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_manga_info_executes_under_dry_run PASSED [ 59%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_vc_pic_dry_run_blocks_download PASSED [ 60%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_vc_read_only_executes_under_dry_run PASSED [ 62%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_login_dry_run_never_blocks PASSED [ 63%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_config_needs_no_bilic PASSED [ 64%]
cli_anything/bilic/tests/test_core.py::TestCommands::test_user_and_fav PASSED [ 65%]
cli_anything/bilic/tests/test_core.py::TestCliSurface::test_help_lists_commands PASSED [ 67%]
cli_anything/bilic/tests/test_core.py::TestCliSurface::test_json_doctor PASSED [ 68%]
cli_anything/bilic/tests/test_core.py::TestCliSurface::test_json_flag_after_subcommand PASSED [ 69%]
cli_anything/bilic/tests/test_core.py::TestCliSurface::test_config_json PASSED [ 70%]
cli_anything/bilic/tests/test_core.py::TestCliSurface::test_dry_run_down_writes_no_session PASSED [ 71%]
cli_anything/bilic/tests/test_core.py::TestCliSurface::test_failing_command_exits_one PASSED [ 73%]
cli_anything/bilic/tests/test_core.py::TestCliSurface::test_missing_binary_exits_two PASSED [ 74%]
cli_anything/bilic/tests/test_core.py::TestCliSurface::test_session_show_and_reset PASSED [ 75%]
cli_anything/bilic/tests/test_core.py::TestCliSurface::test_unknown_command_fails PASSED [ 76%]
cli_anything/bilic/tests/test_full_e2e.py::TestRealBilicBackend::test_binary_resolves_to_an_executable PASSED [ 78%]
cli_anything/bilic/tests/test_full_e2e.py::TestRealBilicBackend::test_real_tree_invocation PASSED [ 79%]
cli_anything/bilic/tests/test_full_e2e.py::TestRealBilicBackend::test_real_doctor_invocation PASSED [ 80%]
cli_anything/bilic/tests/test_full_e2e.py::TestRealSearchE2E::test_search_reports_real_network_outcome PASSED [ 81%]
cli_anything/bilic/tests/test_full_e2e.py::TestTreeE2E::test_tree_json_is_parsed PASSED [ 82%]
cli_anything/bilic/tests/test_full_e2e.py::TestTreeE2E::test_tree_human PASSED [ 84%]
cli_anything/bilic/tests/test_full_e2e.py::TestReplE2E::test_repl_exits_cleanly_on_eof PASSED [ 85%]
cli_anything/bilic/tests/test_full_e2e.py::TestReplE2E::test_repl_runs_a_piped_command PASSED [ 86%]
cli_anything/bilic/tests/test_full_e2e.py::TestHelpE2E::test_help PASSED [ 87%]
cli_anything/bilic/tests/test_full_e2e.py::TestHelpE2E::test_version PASSED [ 89%]
cli_anything/bilic/tests/test_full_e2e.py::TestConfigE2E::test_config_is_read_only_and_reports_proxy PASSED [ 90%]
cli_anything/bilic/tests/test_full_e2e.py::TestCLISubprocess::test_help PASSED [ 91%]
cli_anything/bilic/tests/test_full_e2e.py::TestCLISubprocess::test_doctor_json PASSED [ 92%]
cli_anything/bilic/tests/test_full_e2e.py::TestCLISubprocess::test_tree_json PASSED [ 93%]
cli_anything/bilic/tests/test_full_e2e.py::TestCLISubprocess::test_config_json PASSED [ 95%]
cli_anything/bilic/tests/test_full_e2e.py::TestCLISubprocess::test_down_dry_run_does_not_download PASSED [ 96%]
cli_anything/bilic/tests/test_full_e2e.py::TestCLISubprocess::test_session_show_json PASSED [ 97%]
cli_anything/bilic/tests/test_full_e2e.py::TestCLISubprocess::test_version PASSED [ 98%]
cli_anything/bilic/tests/test_full_e2e.py::TestCLISubprocess::test_unknown_subcommand_fails PASSED [100%]

============================= 82 passed in 14.77s ==============================
```
