"""Read-only view of bilic's application config (~/.bc/bilic.conf).

The harness never writes to ~/.bc: this module only reports what the file says
so an agent can see (for example) which proxy the target software will use.
"""

import json
from pathlib import Path


def default_config_path():
    return Path.home() / ".bc" / "bilic.conf"


def config_view(path=None):
    """Return the bilic config path, raw text and parsed JSON (read-only)."""
    target = Path(path) if path is not None else default_config_path()
    view = {
        "path": str(target),
        "exists": target.is_file(),
        "read_only": True,
        "raw": None,
        "content": None,
        "parse_error": None,
        "proxy": None,
        "proxy_type": None,
    }
    if not view["exists"]:
        return view

    try:
        raw = target.read_text(encoding="utf-8")
    except OSError as exc:
        view["parse_error"] = f"could not read {target}: {exc}"
        return view

    view["raw"] = raw
    try:
        content = json.loads(raw)
    except ValueError as exc:
        view["parse_error"] = f"config is not valid JSON: {exc}"
        return view

    if isinstance(content, dict):
        view["content"] = content
        view["proxy"] = content.get("proxy")
        view["proxy_type"] = content.get("proxy_type")
    else:
        view["parse_error"] = "config JSON is not an object"
    return view
