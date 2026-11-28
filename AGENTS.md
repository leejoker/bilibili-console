# bilibili-console Agent Guide

Ruby gem + Thor CLI (`bilic`) for bilibili, plus an agent harness under `agent-harness/` (Python/Click) that drives the real `bilic`.

## Environment
- Ruby 4.0.10 (mise) / Bundler 4.0.20; gems resolve from `https://rubygems.org` (`.bundle/config` only sets `BUNDLE_WITHOUT`).
- Python 3.14 with `click`, `prompt_toolkit`, `pytest` for the harness.
- This host cannot reach bilibili directly. `~/.bc/bilic.conf` must hold the proxy, e.g. `{"proxy": "127.0.0.1:7890"}`; `bilic config --json` / `cli-anything-bilic --json config` prints the effective value.

## Build & run
- From source: `bundle exec ruby bin/bilic <command>` (no install needed while iterating).
- Build/install the gem: `gem build bilibili_console.gemspec && gem install --local ./bilibili_console-0.0.3.gem && rm ./bilibili_console-0.0.3.gem`.
- After changing `lib/`, reinstall the gem — the `bilic` on `PATH` keeps running the previously installed copy.
- Harness install: `pip install -e agent-harness --user --break-system-packages` (Debian Python is EXTERNALLY-MANAGED).

## Test & lint
- Ruby test suite is empty: `bundle exec rake spec` → `0 examples, 0 failures`. Do not claim behavioural coverage from it.
- Lint: `bundle exec rubocop lib`. Caveat: the repo ships `rubocop.yml`, but RuboCop only auto-loads `.rubocop.yml`, so the shipped config is ignored and the run uses defaults (~131 offenses, mostly `Style/FrozenStringLiteralComment`).
- Syntax check any edited file: `ruby -c <file>`.
- Harness tests: `cd agent-harness && CLI_ANYTHING_FORCE_INSTALLED=1 python3 -m pytest cli_anything/bilic/tests -v --tb=short` (82 cases: 63 offline unit tests + 19 real-backend/installed-CLI tests).

## Layout
- `bin/bilic` — Thor entry point; all command declarations live here.
- `lib/bilibili_console/` — domain modules (`login`, `search`, `video`, `fav`, `manga`, `video_comment`), `http/http.rb` (Net::HTTP client + proxy + risk-control handling), `base/` (shared base classes), `api.rb` (endpoints), `config.rb` (defaults, `~/.bc` paths, `$log`).
- `agent-harness/` — `cli_anything/bilic/{bilic_cli.py, core/, utils/, tests/}`; backend wraps the real `bilic` binary, never HTTP in Python.

## Conventions
- Ruby: two-space indent, single quotes, `# frozen_string_literal: true` at the top of `lib/` files, `$log` (Logger) for diagnostics.
- Upstream failures raise typed errors: `BiliHttp::RequestBlockedError` (risk control) or `BiliHttp::ApiError` (non-zero business code). Do not let raw `JSON::ParserError`/`NoMethodError` escape.
- Never redefine `Kernel#raise`/`fail` in `bin/bilic` — it masks real exceptions (this bit us once).
- Harness: PEP 420 namespace (`cli_anything/` has no `__init__.py`), every command supports `--json`, mutating commands support `--dry-run` and write session state through `core/session.py` (flock). `--dry-run` on mutations must execute nothing.
- No `preview` group: the target owns no local renderable state; documented in `agent-harness/README` and `SKILL.md`.
- Commit messages: Chinese, `<type>: <subject>` with feat/fix/docs/style/refactor/test/chore, subject ≤50 chars, no trailing period.

## Known gotchas
- bilibili risk control answers either an HTML challenge page or JSON `{"code":-412,"message":"request was banned"}`. The HTTP client retries 2× (3 s) then raises `RequestBlockedError`. Bursts of requests get banned for minutes — probe with single calls, not loops.
- Requests need the full browser header set (modern UA + `Accept`/`Accept-Language`/`sec-ch-ua*`/`sec-fetch-*`, `Origin`, `Referer` with trailing slash). Changing only the UA does not help.
- Login polling codes: `0` success, `86101` 未扫码, `86090` 已扫码未确认, `86038` 过期. Cookies are saved only after a confirmed login; the QR poster is spawned in the background so polling starts immediately.
- rubyzip 3.x removed `Zip::InputStream#glob`; iterate `get_next_entry` and match `entry.name`.
- Ruby 4.0 no longer ships `logger` as a default gem — it is an explicit gemspec dependency.
- `https_proxy`/`HTTPS_PROXY` env vars are ignored by the current `Net::HTTP.start` call path; only the `proxy` key in `~/.bc/bilic.conf` is honoured.
- B站 CDN 播放直链必须带 `Referer: https://www.bilibili.com/`，裸 GET 一律 403（实测 471 字节 edge 错误页）。`bilibili_console/local_player.rb` 给 mpv/vlc 注入该头，其它播放器只拿到裸地址。
- `bilic play` 默认依次找 `mpv` / `vlc` / `xdg-open`，Windows 上没有 `xdg-open`，所以要么装 mpv/vlc，要么在 `~/.bc/bilic.conf` 里配 `"player"`。
- Downloads are task-based: state lives in `~/.bc/tasks.json` (locked writes, see `download_task.rb`), segments resume with `wget -c`, and multi-segment pages merge with `ffmpeg` — missing ffmpeg raises a clear error instead of silently producing nothing. Task management: `bilic tasks [<id>] [--retry|--cancel|--remove]`.

## Verify before claiming done
1. `ruby -c` on every changed Ruby file.
2. `bundle exec ruby bin/bilic tree` — offline smoke test of the CLI wiring.
3. Network paths (`search`, `user`, `fav`): one call through the configured proxy; treat `-412` as rate limiting, not as a code bug.
4. Harness changes: run the pytest command above with `CLI_ANYTHING_FORCE_INSTALLED=1`.