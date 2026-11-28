---
name: "cli-anything-bilic"
description: "Drive the bilic (bilibili-console) Ruby CLI through a JSON-first harness: command tree, environment/config inspection, search, favourites, comments, manga check-in and video downloads."
---

# cli-anything-bilic

A CLI-Anything harness around **bilic** (`bilibili_console`, a Ruby/Thor CLI for
bilibili). The harness runs the real `bilic` executable as a subprocess and
turns its human-readable output into JSON. It never re-implements bilibili HTTP
calls.

## Prerequisites

- `bilic` installed (`gem install bilibili_console`) and on `PATH`, or exported
  as `BILIC_BIN=/path/to/bilic`
- `~/.bc/bilic.conf` — on networks where bilibili is blocked this must contain
  the proxy, e.g. `{"proxy": "127.0.0.1:7890", "proxy_type": "http"}`
- `cli-anything-bilic` installed (`pip install -e agent-harness`)

## How to think about this CLI

1. **Inspect before acting.** `tree --json`, `doctor --json`, `config --json`
   are free (no network for `config`) and describe the target CLI, the
   environment, and the effective proxy.
2. **Everything is `--json`.** Every command emits one object with `ok`,
   `command`, `dry_run`, `upstream` (binary/argv/exit_code/executed) and either
   `data` or `error`.
3. **Rehearse mutations.** `--dry-run` on a mutating command prints the exact
   argv and executes nothing.
4. **Read `error.kind`**, not the exit code of the target: `bilic` exits 0 even
   when it raises. Kinds: `binary_not_found`, `timeout`,
   `upstream_response_error`, `bilic_error`, `nonzero_exit`.

## Command surface

| Command | Purpose | Mutating |
|---------|---------|----------|
| `tree` | Parsed Thor command tree of the target CLI (introspection) | no |
| `doctor` | Real `bilic doctor` call + `~/.bc/bilic.conf` snapshot | no |
| `config` | Read-only view of `~/.bc/bilic.conf` (no bilic call) | no |
| `login` | QR-code login; **blocks** until scanned (`--timeout`, default 180s) | yes |
| `user` | Account profile (uid/uname/level/coins/moral) | no |
| `search <keyword>` | Video search; `--page`, `--sort`, `--bv`, `--av`, `--pic` | `--pic` only |
| `down <id>` | Download by BV/av id; `--start`, `--end`, `--page`, `--qn`, `--rename`, `--list`, `--remove`, `--workers` | yes (`--list` is read-only) |
| `fav` | Favourite folders or their media; `--search`, `--fav`, `--page-size`, `--page-num`, `--all` | no |
| `vc <oid>` | Video comments; `--page`, `--pic` | `--pic` only |
| `manga` | Manga check-in; `--info` for status only | yes (except `--info`) |
| `session show` / `session reset` | Harness session state | reset only |

Run with no subcommand to enter the REPL; `quit`/`exit` or EOF leaves it
cleanly with status 0.

## Agent recipes

```bash
# 1. learn the target CLI
cli-anything-bilic --json tree | jq '.data.commands[] | {cli_name, description}'

# 2. check the environment and the proxy that bilic will use
cli-anything-bilic --json doctor   | jq '.upstream, .environment.config'
cli-anything-bilic --json config   | jq '.data | {path, proxy, proxy_type}'

# 3. real network read
cli-anything-bilic --json search ruby --page 1 | jq '.data.results[] | {bv: .bv, title: .title_plain}'

# 4. rehearse a download, then run it explicitly
cli-anything-bilic --dry-run --json down BV1xx411c7mD --qn 480 | jq '.upstream.argv'
cli-anything-bilic --json down BV1xx411c7mD --qn 480

# 5. what did I already run?
cli-anything-bilic --json session show | jq '.data.session.last_command'
```

## Reading results

```json
{"ok": true, "command": "search", "dry_run": false,
 "upstream": {"binary": "/…/bilic", "argv": ["/…/bilic","search","ruby"],
              "exit_code": 0, "executed": true},
 "data": {"results": [{"av": 114118438687985, "bv": "BV1…", "title": "…",
                       "title_plain": "…", "author": "…", "page_size": 3}]}}
```

- `title` is bilic's raw title (may contain `<em class="keyword">` highlighting);
  `title_plain` is the tag-stripped version — prefer it when matching text.
- `vc` returns `data.comments[]` (`sender_id`, `sender_name`, `send_time`,
  `content`, `content_pic`).
- `fav` returns `data.folders[]` (`fav_id`, `fav_name`, `media_count`) and/or
  `data.items[]` (`bv`, `title`, `intro`).
- `manga` returns `message`/`status`/`day_count`/`already_checked_in`.
- `down` returns the raw progress lines in `data.output_lines`.

## Failures

```json
{"ok": false, "command": "search",
 "error": {"kind": "upstream_response_error",
           "message": "bilic received a non-JSON response … (bilibili risk control / WAF …)"}}
```

`upstream_response_error` means bilibili answered with an HTML risk-control page
(HTTP 412) and the Ruby JSON parser died — retry later, check the proxy in
`~/.bc/bilic.conf`, and do not treat it as "no results".

## Session state

`~/.config/cli-anything-bilic/session.json` (override with
`CLI_ANYTHING_BILIC_STATE_DIR`) keeps `last_command`, the last 20
`last_outputs`, and the default `qn` for `down`. Writes are flock-protected.
`--dry-run` writes nothing.

## No preview command group

This harness intentionally ships **no** `preview …` surface. bilic owns no
local project or renderable intermediate state — only remote account state and
one-off artifacts it writes itself (`~/.bc/downloads`, `~/.bc/pic`, the login
QR code). A preview bundle would have to be fabricated or screen-scraped, which
violates the truthfulness principle. Use the `--json` payloads,
`config --json` and `session show --json` for inspection instead.

## Boundaries to respect

- Do not edit files under `~/.bc/`: they belong to the target software.
- Do not run `login` casually — it blocks waiting for a QR scan (use `--dry-run`
  or a short `--timeout`).
- `down` writes into `~/.bc/downloads` and costs bandwidth; always rehearse with
  `--dry-run` first.
