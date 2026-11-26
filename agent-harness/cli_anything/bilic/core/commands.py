"""Command layer: build bilic argv, invoke the real CLI, parse its text output.

Every public function returns one JSON-ready envelope:

    {"ok": bool, "command": str, "dry_run": bool,
     "upstream": {"binary", "argv", "exit_code", "executed", ...},
     "data": {...}}                 # when ok
    {"ok": False, "error": {"kind", "message", ...}}   # on failure

Mutating commands (login, down, manga without --info, and the picture-download
variants) are never executed under --dry-run: the only thing dry-run can prove
is the exact argv that would have run.
"""

from ..utils import bilic_backend
from . import config_view as config_view_mod
from . import parsers

DRY_RUN_NOTE = "dry-run: bilic was not invoked and no session state was written"


def _tail(text, limit=2000):
    text = text or ""
    if len(text) <= limit:
        return text
    return text[-limit:]


def _upstream(result):
    return {
        "binary": result["binary"],
        "argv": result["argv"],
        "exit_code": result["exit_code"],
        "executed": True,
        "duration_ms": result["duration_ms"],
        "stdout_bytes": len(result["stdout"].encode("utf-8")),
        "stderr_tail": _tail(result["stderr"]),
    }


def _dry_run(command, args):
    binary = bilic_backend.find_bilic()
    return {
        "ok": True,
        "command": command,
        "dry_run": True,
        "upstream": {
            "binary": binary,
            "argv": [binary, *args],
            "executed": False,
            "exit_code": None,
        },
        "note": DRY_RUN_NOTE,
    }


def _execute(command, args, parser=None, timeout=bilic_backend.DEFAULT_TIMEOUT, mutating=False, dry_run=False):
    if dry_run and mutating:
        return _dry_run(command, args)

    result = bilic_backend.run_bilic(args, timeout=timeout)
    payload = {
        "ok": result["ok"],
        "command": command,
        "dry_run": bool(dry_run),
        "upstream": _upstream(result),
    }
    if result["ok"]:
        payload["data"] = parser(result["stdout"]) if parser else {"stdout": result["stdout"]}
    else:
        payload["error"] = {
            "kind": result["error_kind"],
            "message": result["error"],
            "stdout_excerpt": _tail(result["stdout"], 1000),
        }
    return payload


def tree(dry_run=False):
    """Thor command tree (introspection - no network, no account needed)."""
    return _execute("tree", ["tree"], parser=parsers.parse_tree, dry_run=dry_run)


def doctor(dry_run=False):
    """Environment check.

    bilic's doctor only verifies the wget/aria2 download helpers and is a no-op
    off Windows, so the honest payload records the real invocation plus the
    effective application config.
    """
    payload = _execute("doctor", ["doctor"], parser=parsers.parse_doctor, dry_run=dry_run)
    payload["environment"] = {
        "config": config_view_mod.config_view(),
        "note": (
            "bilic doctor only checks the wget/aria2 download helpers "
            "(lib/bilibili_console/util/doctor_utils.rb) and does nothing on Linux; "
            "an empty output list with exit code 0 is the real result."
        ),
    }
    return payload


def login(timeout=180, dry_run=False):
    """Login with a QR code. Blocks until the code is scanned."""
    return _execute(
        "login",
        ["login"],
        parser=parsers.parse_login,
        timeout=timeout,
        mutating=True,
        dry_run=dry_run,
    )


def user(dry_run=False):
    """Account profile (needs a valid cookie in ~/.bc/cookie.json)."""
    return _execute("user", ["user"], parser=parsers.parse_user, dry_run=dry_run)


def search(keyword, page=None, sort=None, bv=False, av=False, pic=False, dry_run=False):
    """Search bilibili videos."""
    args = ["search", str(keyword)]
    if page is not None:
        args += ["--page", str(page)]
    if sort:
        args += ["--sort", str(sort)]
    if bv:
        args.append("--bv")
    if av:
        args.append("--av")
    if pic:
        args.append("--pic")
    return _execute(
        "search",
        args,
        parser=lambda text: {"results": parsers.parse_search(text)},
        timeout=300,
        mutating=bool(pic),
        dry_run=dry_run,
    )


def down(
    video_id,
    start=None,
    end=None,
    page=None,
    qn=None,
    rename=None,
    list_downloads=False,
    dry_run=False,
):
    """Download a video by BV/av id (or list downloads with --list)."""
    args = ["down", str(video_id)]
    if start is not None:
        args += ["--start", str(start)]
    if end is not None:
        args += ["--end", str(end)]
    if page is not None:
        args += ["--page", str(page)]
    if qn is not None:
        args += ["--qn", str(qn)]
    if rename:
        args += ["--rename", str(rename)]
    if list_downloads:
        args.append("--list")
    return _execute(
        "down",
        args,
        parser=lambda text: {"output_lines": [line for line in (text or "").splitlines() if line.strip()]},
        timeout=1800,
        mutating=not list_downloads,
        dry_run=dry_run,
    )


def fav(search=None, favorite=None, page_size=None, page_num=None, all_fav=False, dry_run=False):
    """Favourite folders, or media inside them."""
    args = ["fav"]
    if search:
        args += ["--search", str(search)]
    if favorite:
        args += ["--fav", str(favorite)]
    if page_size is not None:
        args += ["--page-size", str(page_size)]
    if page_num is not None:
        args += ["--page-num", str(page_num)]
    if all_fav:
        args.append("--all")
    return _execute("fav", args, parser=parsers.parse_fav, timeout=300, dry_run=dry_run)


def vc(oid, page=None, pic=False, dry_run=False):
    """Video comments (or download the pictures inside them)."""
    args = ["vc", str(oid)]
    if page is not None:
        args += ["--page", str(page)]
    if pic:
        args.append("--pic")
    return _execute(
        "vc",
        args,
        parser=parsers.parse_vc,
        timeout=300,
        mutating=bool(pic),
        dry_run=dry_run,
    )


def manga(info=False, dry_run=False):
    """Manga check-in (mutates the remote account) or its status with --info."""
    args = ["manga"]
    if info:
        args.append("--info")
    return _execute(
        "manga",
        args,
        parser=parsers.parse_manga,
        mutating=not info,
        dry_run=dry_run,
    )


def config():
    """Read-only view of ~/.bc/bilic.conf (no bilic invocation)."""
    view = config_view_mod.config_view()
    return {"ok": True, "command": "config", "dry_run": False, "data": view}
