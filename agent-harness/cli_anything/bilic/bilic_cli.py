"""CLI-Anything bilic - Click front end for the real bilic (bilibili-console) CLI.

Entry point: cli-anything-bilic

Every command supports --json; mutating commands support --dry-run and every
successful invocation is recorded in the harness session file.
"""

import json
import os
import shlex
import sys
from pathlib import Path

import click

from . import __version__
from .core import commands as cmd
from .core import session as session_mod
from .utils import bilic_backend

CONTEXT_SETTINGS = {"help_option_names": ["-h", "--help"]}


# ── Shared helpers ───────────────────────────────────────────────────────

def _use_json(ctx, local_flag=False):
    return bool(local_flag or (ctx.obj or {}).get("json"))


def _use_dry_run(ctx):
    return bool((ctx.obj or {}).get("dry_run"))


def _session(ctx):
    if ctx.obj.get("session") is None:
        ctx.obj["session"] = session_mod.load_session()
    return ctx.obj["session"]


def _jecho(payload):
    click.echo(json.dumps(payload, indent=2, ensure_ascii=False, default=str))


def _truncate(value, width=44):
    text = str(value if value is not None else "")
    return text if len(text) <= width else text[: width - 1] + "…"


def _table(headers, rows):
    if not rows:
        click.echo("  (no rows)")
        return
    widths = [
        max([len(str(headers[index]))] + [len(_truncate(row[index])) for row in rows])
        for index in range(len(headers))
    ]
    header_line = "  ".join(str(headers[i]).ljust(widths[i]) for i in range(len(headers)))
    click.echo("  " + header_line)
    click.echo("  " + "-" * len(header_line))
    for row in rows:
        click.echo(
            "  " + "  ".join(_truncate(row[i]).ljust(widths[i]) for i in range(len(headers)))
        )


def _summarize(payload):
    data = payload.get("data")
    if not isinstance(data, dict):
        return None
    summary = {}
    for key, value in data.items():
        if isinstance(value, list):
            summary[key] = len(value)
        elif isinstance(value, (str, int, float, bool)):
            summary[key] = value
    return summary or None


# ── Human renderers ──────────────────────────────────────────────────────

def _render_tree(data):
    click.echo(f"  {data.get('root') or 'bilic'}")
    for item in data.get("commands", []):
        click.echo(
            f"   ├─ {item['name']}  (cli: bilic {item.get('cli_name')})"
            f"  - {item.get('description') or ''}"
        )


def _render_search(data):
    results = data.get("results", [])
    rows = [
        [
            item.get("av"),
            item.get("bv"),
            item.get("title_plain") or item.get("title"),
            item.get("author"),
            item.get("page_size"),
        ]
        for item in results
    ]
    _table(["av", "bv", "title", "author", "pages"], rows)
    click.echo(f"  {len(results)} result(s)")


def _render_fav(data):
    folders = data.get("folders", [])
    items = data.get("items", [])
    if folders:
        _table(
            ["fav_id", "fav_name", "media_count"],
            [[f.get("fav_id"), f.get("fav_name"), f.get("media_count")] for f in folders],
        )
    if items:
        _table(
            ["bv", "title", "intro"],
            [[i.get("bv"), i.get("title"), i.get("intro")] for i in items],
        )
    if not folders and not items:
        click.echo("  (no fav output)")


def _render_user(data):
    for key, value in data.items():
        click.echo(f"  {key}: {value}")


def _render_vc(data):
    if data.get("pictures_downloaded"):
        click.echo("  pictures downloaded by bilic")
        return
    comments = data.get("comments", [])
    _table(
        ["sender_id", "sender_name", "send_time", "content"],
        [
            [c.get("sender_id"), c.get("sender_name"), c.get("send_time"), c.get("content")]
            for c in comments
        ],
    )
    click.echo(f"  {len(comments)} comment(s)")


def _render_manga(data):
    for key in ("message", "status", "day_count"):
        if data.get(key) is not None:
            click.echo(f"  {key}: {data[key]}")
    already = data.get("already_checked_in")
    if already is not None:
        click.echo(f"  already_checked_in: {already}")


def _render_doctor(data):
    click.echo(f"  doctor output lines: {len(data.get('output_lines', []))}")
    if data.get("output_empty"):
        click.echo("  (bilic doctor produced no output - its checks are Windows-only)")


def _render_config(data):
    click.echo(f"  path: {data.get('path')}")
    click.echo(f"  exists: {data.get('exists')}")
    click.echo(f"  proxy: {data.get('proxy')} (type: {data.get('proxy_type')})")
    if data.get("parse_error"):
        click.echo(f"  parse_error: {data['parse_error']}")
    if data.get("raw"):
        click.echo("  raw:")
        for line in str(data["raw"]).splitlines():
            click.echo(f"    {line}")


def _render_session(data):
    click.echo(f"  path: {data.get('path')}")
    click.echo(f"  exists: {data.get('exists')}")
    session = data.get("session") or {}
    last = session.get("last_command")
    click.echo(f"  defaults: {session.get('defaults')}")
    if last:
        click.echo(f"  last_command: {last.get('command')} ok={last.get('ok')} at={last.get('at')}")
        click.echo(f"    argv: {' '.join(last.get('argv', []))}")
    else:
        click.echo("  last_command: (none)")
    click.echo(f"  recorded outputs: {len(session.get('last_outputs', []))}")


_RENDERERS = {
    "tree": _render_tree,
    "search": _render_search,
    "fav": _render_fav,
    "user": _render_user,
    "vc": _render_vc,
    "manga": _render_manga,
    "doctor": _render_doctor,
    "config": _render_config,
    "session show": _render_session,
    "session reset": _render_session,
}


def _render(payload):
    command = payload.get("command")
    if payload.get("dry_run"):
        argv = " ".join(str(part) for part in payload.get("upstream", {}).get("argv", []))
        click.echo(f"dry-run: would run: {argv}")
        click.echo(f"note: {payload.get('note')}")
        return
    if not payload.get("ok", True):
        error = payload.get("error") or {}
        click.echo(f"ERROR [{error.get('kind')}]: {error.get('message')}", err=True)
        return
    data = payload.get("data") or {}
    renderer = _RENDERERS.get(command)
    if renderer is not None:
        renderer(data)
    else:
        click.echo(json.dumps(data, indent=2, ensure_ascii=False, default=str))


# ── Finalisation: render, record, auto-save ──────────────────────────────

def _finalize(ctx, payload, local_json=False, record=True, defaults=None, exit_on_error=True):
    as_json = _use_json(ctx, local_json)
    if as_json:
        _jecho(payload)
    else:
        _render(payload)

    dry_run = bool(payload.get("dry_run"))
    upstream = payload.get("upstream") or {}
    if record and upstream.get("argv") and not dry_run:
        session_mod.record_run(
            _session(ctx),
            command=payload.get("command"),
            argv=upstream["argv"],
            ok=bool(payload.get("ok")),
            summary=_summarize(payload),
            defaults=defaults,
        )
        ctx.obj["dirty"] = True

    if ctx.obj.get("dirty") and not dry_run:
        session_mod.save_session(_session(ctx))
        ctx.obj["dirty"] = False

    if exit_on_error and not payload.get("ok", True):
        ctx.exit(1)


def _invoke(ctx, command, call, local_json, defaults=None, record=True):
    try:
        payload = call()
    except bilic_backend.BilicNotFoundError as exc:
        payload = {
            "ok": False,
            "command": command,
            "error": {"kind": "binary_not_found", "message": str(exc)},
        }
        _finalize(ctx, payload, local_json, record=False, exit_on_error=False)
        raise SystemExit(2)
    _finalize(ctx, payload, local_json, defaults=defaults, record=record)


# ── Main group ───────────────────────────────────────────────────────────

@click.group(
    invoke_without_command=True,
    context_settings=CONTEXT_SETTINGS,
)
@click.option("--json", "as_json", is_flag=True, default=False, help="Output as JSON.")
@click.option(
    "--dry-run",
    "dry_run",
    is_flag=True,
    default=False,
    help="Do not execute mutating commands and do not write session state.",
)
@click.version_option(__version__, "--version", "-V", prog_name="cli-anything-bilic")
@click.pass_context
def cli(ctx, as_json, dry_run):
    """CLI-Anything bilic - drive the real bilic (bilibili-console) Thor CLI.

    Run without a subcommand to enter the interactive REPL.
    """
    ctx.ensure_object(dict)
    ctx.obj.update(json=as_json, dry_run=dry_run, dirty=False, session=None)
    if ctx.invoked_subcommand is None:
        _repl_loop()


@cli.result_callback()
def _auto_save_on_exit(result, **kwargs):
    """Persist the harness session after one-shot commands (skipped by --dry-run)."""
    ctx = click.get_current_context(silent=True)
    if ctx is None or not isinstance(ctx.obj, dict):
        return
    if ctx.obj.get("dirty") and not ctx.obj.get("dry_run"):
        session_mod.save_session(ctx.obj["session"])
        ctx.obj["dirty"] = False


# ── Commands ─────────────────────────────────────────────────────────────

@cli.command("doctor")
@click.option("--json", "local_json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_context
def doctor_command(ctx, local_json):
    """Check the environment and print bilic's effective configuration."""
    _invoke(ctx, "doctor", lambda: cmd.doctor(dry_run=_use_dry_run(ctx)), local_json)


@cli.command("tree")
@click.option("--json", "local_json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_context
def tree_command(ctx, local_json):
    """Print the parsed command tree of the target bilic CLI (introspection)."""
    _invoke(ctx, "tree", lambda: cmd.tree(dry_run=_use_dry_run(ctx)), local_json)


@cli.command("config")
@click.option("--json", "local_json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_context
def config_command(ctx, local_json):
    """Show ~/.bc/bilic.conf (read-only: the harness never writes it)."""
    _invoke(ctx, "config", cmd.config, local_json, record=False)


@cli.command("login")
@click.option("--timeout", type=int, default=180, show_default=True, help="Seconds before giving up.")
@click.option("--json", "local_json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_context
def login_command(ctx, timeout, local_json):
    """Log in with a QR code (blocks until the code is scanned)."""
    _invoke(ctx, "login", lambda: cmd.login(timeout=timeout, dry_run=_use_dry_run(ctx)), local_json)


@cli.command("user")
@click.option("--json", "local_json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_context
def user_command(ctx, local_json):
    """Show the logged-in account profile."""
    _invoke(ctx, "user", lambda: cmd.user(dry_run=_use_dry_run(ctx)), local_json)


@cli.command("search")
@click.argument("keyword")
@click.option("--page", type=int, default=None, help="Page number (default 1).")
@click.option("--sort", default=None, help="totalrank|click|pubdate|dm|stow|scores|attention.")
@click.option("--bv", is_flag=True, default=False, help="Keep only the result matching this BV id.")
@click.option("--av", is_flag=True, default=False, help="Keep only the result matching this av id.")
@click.option("--pic", is_flag=True, default=False, help="Save the cover of the matched BV id.")
@click.option("--json", "local_json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_context
def search_command(ctx, keyword, page, sort, bv, av, pic, local_json):
    """Search bilibili videos (real network call through bilic)."""
    _invoke(
        ctx,
        "search",
        lambda: cmd.search(
            keyword,
            page=page,
            sort=sort,
            bv=bv,
            av=av,
            pic=pic,
            dry_run=_use_dry_run(ctx),
        ),
        local_json,
    )


@cli.command("down")
@click.argument("video_id")
@click.option("--start", type=int, default=None, help="First page (bilic default 1).")
@click.option("--end", type=int, default=None, help="Last page.")
@click.option("--page", type=int, default=None, help="Download a single page.")
@click.option("--qn", default=None, help="Quality: 240|360|480|720|720P60|1080|1080+|1080P60|4K|HDR.")
@click.option("--rename", default=None, help="Rename the downloaded file.")
@click.option("--list", "list_downloads", is_flag=True, default=False, help="List downloaded videos.")
@click.option("--json", "local_json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_context
def down_command(ctx, video_id, start, end, page, qn, rename, list_downloads, local_json):
    """Download a video by BV/av id (mutating; use --dry-run to inspect)."""
    effective_qn = session_mod.resolve_qn(qn, _session(ctx))
    _invoke(
        ctx,
        "down",
        lambda: cmd.down(
            video_id,
            start=start,
            end=end,
            page=page,
            qn=effective_qn,
            rename=rename,
            list_downloads=list_downloads,
            dry_run=_use_dry_run(ctx),
        ),
        local_json,
        defaults={"qn": effective_qn},
    )


@cli.command("fav")
@click.option("--search", default=None, help="Search inside favourites.")
@click.option("--fav", "favorite", default=None, help="Operate on one favourite folder id.")
@click.option("--page-size", type=int, default=None, help="Page size.")
@click.option("--page-num", type=int, default=None, help="Page number.")
@click.option("--all", "all_fav", is_flag=True, default=False, help="Search across all favourites.")
@click.option("--json", "local_json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_context
def fav_command(ctx, search, favorite, page_size, page_num, all_fav, local_json):
    """List favourite folders, or the media inside them."""
    _invoke(
        ctx,
        "fav",
        lambda: cmd.fav(
            search=search,
            favorite=favorite,
            page_size=page_size,
            page_num=page_num,
            all_fav=all_fav,
            dry_run=_use_dry_run(ctx),
        ),
        local_json,
    )


@cli.command("vc")
@click.argument("oid")
@click.option("--page", type=int, default=None, help="Page number.")
@click.option("--pic", is_flag=True, default=False, help="Download pictures inside the comments.")
@click.option("--json", "local_json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_context
def vc_command(ctx, oid, page, pic, local_json):
    """Show video comments for a video id."""
    _invoke(
        ctx,
        "vc",
        lambda: cmd.vc(oid, page=page, pic=pic, dry_run=_use_dry_run(ctx)),
        local_json,
    )


@cli.command("manga")
@click.option("--info", "info", is_flag=True, default=False, help="Only show the check-in status.")
@click.option("--json", "local_json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_context
def manga_command(ctx, info, local_json):
    """Check in to bilibili manga (mutates the account unless --info is given)."""
    _invoke(ctx, "manga", lambda: cmd.manga(info=info, dry_run=_use_dry_run(ctx)), local_json)


# ── Session group ────────────────────────────────────────────────────────

@cli.group("session")
@click.pass_context
def session_group(ctx):
    """Harness session state: show, reset."""


@session_group.command("show")
@click.option("--json", "local_json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_context
def session_show(ctx, local_json):
    """Show the harness session file."""
    path = session_mod.session_path()
    payload = {
        "ok": True,
        "command": "session show",
        "dry_run": False,
        "data": {
            "path": str(path),
            "exists": path.is_file(),
            "session": session_mod.load_session(path),
        },
    }
    _finalize(ctx, payload, local_json, record=False)


@session_group.command("reset")
@click.option("--json", "local_json", is_flag=True, default=False, help="Output as JSON.")
@click.pass_context
def session_reset(ctx, local_json):
    """Reset the harness session to its defaults."""
    path = session_mod.session_path()
    if _use_dry_run(ctx):
        payload = {
            "ok": True,
            "command": "session reset",
            "dry_run": True,
            "upstream": {"argv": [], "executed": False},
            "note": f"dry-run: would reset {path}",
        }
    else:
        payload = {
            "ok": True,
            "command": "session reset",
            "dry_run": False,
            "data": {
                "path": str(path),
                "exists": path.is_file(),
                "session": session_mod.reset_session(path),
            },
        }
    _finalize(ctx, payload, local_json, record=False)


# ── REPL ─────────────────────────────────────────────────────────────────

_REPL_HELP = {
    "tree": "Parsed command tree of the target bilic CLI",
    "doctor": "Environment check plus ~/.bc/bilic.conf snapshot",
    "config": "Show ~/.bc/bilic.conf (read-only)",
    "login": "Log in with a QR code (blocking)",
    "user": "Show the logged-in account profile",
    "search <kw>": "Search bilibili videos",
    "down <id>": "Download a video (mutating)",
    "fav": "Favourite folders / media",
    "vc <oid>": "Video comments",
    "manga": "Manga check-in (mutating without --info)",
    "session show": "Show harness session state",
    "session reset": "Reset harness session state",
    "help": "Show this help",
    "quit / exit": "Exit the REPL",
}


@cli.command("repl")
def repl_command():
    """Interactive REPL (the default when no subcommand is given)."""
    _repl_loop()


def _repl_loop():
    from .utils.repl_skin import ReplSkin

    state_override = os.environ.get(session_mod.STATE_DIR_ENV)
    history_file = str(Path(state_override) / "history") if state_override else None
    skin = ReplSkin("bilic", version=__version__, history_file=history_file)
    skin.print_banner()

    prompt_session = skin.create_prompt_session() if sys.stdin.isatty() else None
    known_commands = set(cli.list_commands(None))

    while True:
        try:
            line = skin.get_input(prompt_session)
        except (EOFError, KeyboardInterrupt):
            skin.print_goodbye()
            return
        line = (line or "").strip()
        if not line:
            continue
        if line in ("quit", "exit", "q"):
            skin.print_goodbye()
            return
        if line in ("help", "?"):
            skin.help(_REPL_HELP)
            continue

        try:
            args = shlex.split(line)
        except ValueError as exc:
            skin.error(f"could not parse input: {exc}")
            continue

        if not any(token in known_commands for token in args):
            skin.warning(f"unknown command: {args[0]}")
            skin.hint("Type 'help' for available commands.")
            continue

        try:
            cli.main(args=args, prog_name="cli-anything-bilic", standalone_mode=False)
        except click.ClickException as exc:
            skin.error(exc.format_message())
        except SystemExit as exc:
            if exc.code:
                skin.error(f"command exited with status {exc.code}")
        except bilic_backend.BilicNotFoundError as exc:
            skin.error(str(exc))
        except Exception as exc:  # keep the REPL alive on unexpected failures
            skin.error(f"{type(exc).__name__}: {exc}")


def main():
    cli(prog_name="cli-anything-bilic")


if __name__ == "__main__":
    main()
