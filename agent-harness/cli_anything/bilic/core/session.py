"""Harness session state (last command, recent outputs, per-command defaults).

Writes follow the cli-anything locked-JSON pattern: open "r+", take an
exclusive flock, and only then truncate, so a concurrent writer can never see
a half-written file.
"""

import json
import os
from datetime import datetime, timezone
from pathlib import Path

SESSION_VERSION = 1
STATE_DIR_ENV = "CLI_ANYTHING_BILIC_STATE_DIR"
OUTPUT_HISTORY_LIMIT = 20

# bin/bilic falls back to "720" when --qn is omitted.
FALLBACK_QN = "720"


def state_dir():
    """Directory holding harness state (overridable for tests)."""
    override = str(os.environ.get(STATE_DIR_ENV) or "").strip()
    if override:
        return Path(override).expanduser()
    return Path.home() / ".config" / "cli-anything-bilic"


def session_path():
    return state_dir() / "session.json"


def default_session():
    return {
        "version": SESSION_VERSION,
        "defaults": {"qn": FALLBACK_QN},
        "last_command": None,
        "last_outputs": [],
    }


def _locked_save_json(path, data, **dump_kwargs):
    """Atomically write JSON with exclusive file locking."""
    path = Path(path)
    try:
        handle = open(path, "r+")
    except FileNotFoundError:
        path.parent.mkdir(parents=True, exist_ok=True)
        handle = open(path, "w")

    with handle:
        locked = False
        try:
            import fcntl

            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            locked = True
        except (ImportError, OSError):
            pass  # Windows / unsupported filesystem - proceed unlocked
        try:
            handle.seek(0)
            handle.truncate()
            json.dump(data, handle, **dump_kwargs)
            handle.flush()
        finally:
            if locked:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def normalize_session(raw):
    """Coerce arbitrary loaded JSON into the canonical session shape."""
    session = default_session()
    if not isinstance(raw, dict):
        return session
    session["version"] = raw.get("version", SESSION_VERSION)
    defaults = raw.get("defaults")
    if isinstance(defaults, dict):
        qn = defaults.get("qn")
        if isinstance(qn, (str, int)) and str(qn).strip():
            session["defaults"]["qn"] = str(qn)
    last_command = raw.get("last_command")
    if isinstance(last_command, dict):
        session["last_command"] = last_command
    outputs = raw.get("last_outputs")
    if isinstance(outputs, list):
        session["last_outputs"] = [item for item in outputs if isinstance(item, dict)][
            -OUTPUT_HISTORY_LIMIT:
        ]
    return session


def load_session(path=None):
    """Load session state; a missing or corrupt file yields the defaults."""
    target = Path(path) if path is not None else session_path()
    try:
        raw = json.loads(target.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default_session()
    return normalize_session(raw)


def save_session(session, path=None):
    """Persist session state with an exclusive lock."""
    target = Path(path) if path is not None else session_path()
    _locked_save_json(target, normalize_session(session), indent=2, sort_keys=True)
    return target


def record_run(
    session,
    command,
    argv,
    ok,
    summary=None,
    defaults=None,
    timestamp=None,
):
    """Record one invocation in the session and return the mutated session."""
    entry = {
        "command": command,
        "argv": list(argv),
        "ok": bool(ok),
        "at": timestamp
        or datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    if summary is not None:
        entry["summary"] = summary

    session.setdefault("version", SESSION_VERSION)
    session.setdefault("defaults", {"qn": FALLBACK_QN})
    session.setdefault("last_outputs", [])
    if defaults:
        session["defaults"].update(defaults)
    session["last_command"] = entry
    outputs = [item for item in session["last_outputs"] if isinstance(item, dict)]
    outputs.append(entry)
    session["last_outputs"] = outputs[-OUTPUT_HISTORY_LIMIT:]
    return session


def reset_session(path=None):
    """Restore the default session and persist it."""
    session = default_session()
    save_session(session, path)
    return session


def resolve_qn(qn, session=None):
    """Effective quality for `down`: explicit flag, then session default."""
    if qn is not None and str(qn).strip():
        return str(qn)
    if session:
        defaults = session.get("defaults") or {}
        stored = defaults.get("qn")
        if stored is not None and str(stored).strip():
            return str(stored)
    return FALLBACK_QN
