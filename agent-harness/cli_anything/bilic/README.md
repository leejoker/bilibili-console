# cli-anything-bilic

A [CLI-Anything](https://github.com/HKUDS/CLI-Anything) harness for **bilic**
(`bilibili_console`, the `bilibili-console` Ruby gem) — a Thor CLI that talks to
bilibili.

The harness is a thin, JSON-first, stateful wrapper around the **real** `bilic`
executable. It does not implement any bilibili HTTP call in Python: every
bilibili interaction is `subprocess.run([bilic, ...])` with `shell=False`, and
the resulting human-readable text is parsed into structured data.

## Requirements

| Requirement | Why |
|-------------|-----|
| `bilic` (`bilibili_console` gem) | **Hard dependency.** The harness is useless without it. |
| Python ≥ 3.10 + `click` + `prompt-toolkit` | CLI/REPL front end. |
| `~/.bc/bilic.conf` | bilic's own config. This machine needs `{"proxy": "127.0.0.1:7890", "proxy_type": "http"}` because direct bilibili access is reset. |

Install the target software:

```bash
gem install bilibili_console        # provides the bilic executable
which bilic                         # must resolve
```

If `bilic` lives somewhere unusual, point the harness at it:

```bash
export BILIC_BIN=/path/to/bilic
```

## Install the harness

```bash
cd agent-harness
pip install -e .            # add --user --break-system-packages on Debian/Ubuntu Pythons
which cli-anything-bilic    # console script must resolve
cli-anything-bilic --help
```

## Usage

One-shot commands (each supports `--json`, before or after the subcommand):

```bash
cli-anything-bilic tree --json                # parsed command tree of the target CLI
cli-anything-bilic --json doctor              # real bilic doctor call + ~/.bc/bilic.conf snapshot
cli-anything-bilic --json config              # read-only view of ~/.bc/bilic.conf
cli-anything-bilic --json search ruby         # real network search
cli-anything-bilic --json user                # account profile (needs a cookie)
cli-anything-bilic --json fav                 # favourite folders
cli-anything-bilic --json vc BV1xx411c7mD     # video comments
cli-anything-bilic --json manga --info        # manga check-in status
cli-anything-bilic --dry-run --json down BV1xx411c7mD --qn 480   # shows argv, downloads nothing
cli-anything-bilic --json session show        # harness session state
cli-anything-bilic session reset              # reset harness session state
```

Interactive mode is the default — run with no subcommand:

```bash
cli-anything-bilic
> tree --json
> search ruby
> quit
```

## JSON contract

Every command prints one JSON object:

```json
{
  "ok": true,
  "command": "tree",
  "dry_run": false,
  "upstream": {
    "binary": "/…/bin/bilic",
    "argv": ["/…/bin/bilic", "tree"],
    "exit_code": 0,
    "executed": true,
    "duration_ms": 485,
    "stdout_bytes": 350,
    "stderr_tail": ""
  },
  "data": {"root": "bili_console", "commands": [], "count": 8}
}
```

Failures never lie about the exit code:

```json
{"ok": false, "command": "search",
 "error": {"kind": "upstream_response_error", "message": "…non-JSON response…"}}
```

`error.kind` is one of `binary_not_found`, `timeout`, `upstream_response_error`,
`bilic_error`, `nonzero_exit`.

Process exit codes: `0` success, `1` the command failed, `2` `bilic` is missing.
Note that bilic itself exits `0` even when it raises (its `at_exit` handler
swallows the status), so the harness classifies `Error! …` lines instead of
trusting the status alone.

## `--dry-run` semantics

| Command kind | `--dry-run` behaviour |
|--------------|----------------------|
| Mutating (`login`, `down`, `manga` without `--info`, `vc --pic`, `search --pic`) | bilic is **not** invoked; the exact argv is reported and no session state is written. |
| Read-only (`tree`, `doctor`, `config`, `user`, `fav`, `search`, `vc`, `manga --info`, `down --list`) | The command runs normally, the session file is left untouched. |
| REPL | Same rules apply per command. |

This is stricter than the generic cli-anything pattern on purpose: the mutating
side of this harness is remote account state and file downloads, so a dry-run
that executed the command would be a real, irreversible action.

## Session state

`~/.config/cli-anything-bilic/session.json` (override with
`CLI_ANYTHING_BILIC_STATE_DIR`) records:

- `last_command` — command name, full argv, ok flag, timestamp, small summary
- `last_outputs` — the last 20 of those entries
- `defaults.qn` — the quality used by `down` when `--qn` is omitted

Writes use the cli-anything locked-JSON pattern (`open("r+")` + `flock` +
truncate inside the lock) so concurrent invocations cannot corrupt the file.
Saving happens immediately after each invocation (one-shot and REPL); failures
are recorded too, so an agent can see what it already tried.

## Why there is no `preview` command group

CLI-Anything harnesses add `preview …` when they own renderable or inspectable
intermediate state. This harness does not, and inventing one would break the
truthfulness principle:

- bilic keeps **no local project/editing state**. The state it has is the remote
  bilibili account (favourites, comments, manga check-in) plus one-off artifacts
  that bilic itself writes (`~/.bc/downloads`, `~/.bc/pic`, the login QR code).
- There is no document to render, no timeline to snapshot, and no offscreen
  export path. A "preview" would either screenshot a terminal or fabricate an
  image — exactly what the methodology forbids.
- The truthful inspection surface already exists: `--json` payloads carry the
  parsed upstream output, and `config`/`doctor`/`session show` expose the real
  state in machine-readable form.

## Tests

```bash
CLI_ANYTHING_FORCE_INSTALLED=1 python3 -m pytest cli_anything/bilic/tests -v --tb=short
```

- `test_core.py` — 63 unit tests, no network, subprocess mocked.
- `test_full_e2e.py` — 19 tests against the real `bilic` and the installed
  console script; they fail (never skip) when `bilic` is missing.

See `tests/TEST.md` for the plan and the recorded results.

## Layout

```
agent-harness/
├── setup.py                 # find_namespace_packages(["cli_anything.*"])
├── conftest.py              # isolated state dir for tests
├── BILIC.md                 # code analysis + harness SOP for this target
├── skills/cli-anything-bilic/SKILL.md    # canonical skill
└── cli_anything/bilic/
    ├── bilic_cli.py         # Click entry point + REPL
    ├── core/
    │   ├── commands.py      # argv builders + envelopes
    │   ├── parsers.py       # bilic text -> structured data
    │   ├── session.py       # locked session state
    │   └── config_view.py   # read-only ~/.bc/bilic.conf
    ├── utils/
    │   ├── bilic_backend.py # the ONLY place that runs bilic
    │   └── repl_skin.py     # unified REPL skin (copied from the plugin)
    ├── skills/SKILL.md      # packaged skill copy
    └── tests/               # TEST.md, test_core.py, test_full_e2e.py
```
