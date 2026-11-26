"""Parsers for bilic's human-readable stdout.

bilic has no --json mode: every command prints formatted text blocks (see
bin/bilic). These helpers turn that text into structured data without pretending
to know more than the text says - fields that are absent stay absent.
"""

import html
import re

# Blocks are separated by a line of dashes (bin/bilic prints 71 dashes).
_SEPARATOR_RE = re.compile(r"^-{10,}\s*$")
_FIELD_RE = re.compile(r"^\s*([A-Za-z][A-Za-z0-9 _-]*?):\s*(.*)$")
_TAG_RE = re.compile(r"<[^>]+>")
_BRANCH_RE = re.compile(r"^(?P<prefix>.*?)[├└]─+\s*(?P<body>.+?)\s*$")

# Keys whose values bilic prints as bare integers.
_NUMERIC_KEYS = {
    "av",
    "page_size",
    "uid",
    "level",
    "coins",
    "moral",
    "fav_id",
    "media_count",
    "sender_id",
}

# Thor's `tree` prints Ruby method names, while the CLI exposes the names given
# to `desc` (bin/bilic: desc 'down', ... def download_video).
CLI_NAME_ALIASES = {
    "download_video": "down",
    "fav_info": "fav",
    "manga_checkin": "manga",
}


def _normalize_key(key):
    return re.sub(r"[\s-]+", "_", key.strip().lower())


def _coerce(key, value):
    if key in _NUMERIC_KEYS and value.isdigit():
        return int(value)
    return value


def _strip_tags(value):
    return html.unescape(_TAG_RE.sub("", value)).strip()


def parse_field_blocks(text):
    """Parse bilic's "key: value" blocks into a list of dicts."""
    blocks = []
    current = {}
    current_key = None

    def flush():
        nonlocal current, current_key
        if current:
            blocks.append(current)
        current = {}
        current_key = None

    for line in (text or "").splitlines():
        if _SEPARATOR_RE.match(line.strip()):
            flush()
            continue
        match = _FIELD_RE.match(line)
        if match:
            key = _normalize_key(match.group(1))
            value = match.group(2).strip()
            current[key] = _coerce(key, value)
            current_key = key
        elif line.strip() and current_key is not None:
            # Continuation of a multi-line value (e.g. a wrapped comment body).
            current[current_key] = f"{current[current_key]}\n{line.strip()}".strip()
    flush()
    return blocks


def parse_search(text):
    """Parse `bilic search <keyword>` output into video result dicts."""
    results = []
    for block in parse_field_blocks(text):
        title = block.get("title", "")
        block["title_plain"] = _strip_tags(str(title))
        results.append(block)
    return results


def parse_fav(text):
    """Parse `bilic fav ...` output into fav folders and/or fav media items."""
    folders = []
    items = []
    for block in parse_field_blocks(text):
        if "fav_id" in block or "fav_name" in block:
            folders.append(block)
        elif "bv" in block or "title" in block:
            items.append(block)
    return {"folders": folders, "items": items}


def parse_user(text):
    """Parse `bilic user` output (uid/uname/level/coins/moral)."""
    blocks = parse_field_blocks(text)
    if not blocks:
        return {}
    return blocks[0]


def parse_vc(text):
    """Parse `bilic vc <oid>` output into comment dicts."""
    if "Pictures Downloaded" in (text or ""):
        return {"pictures_downloaded": True, "comments": []}
    return {"pictures_downloaded": False, "comments": parse_field_blocks(text)}


def parse_manga(text):
    """Parse `bilic manga` / `bilic manga --info` output."""
    fields = {}
    message = None
    unrecognized = []

    for raw_line in (text or "").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        match = re.match(r"^([^:：]+)[:：]\s*(.*)$", line)
        if match:
            key = match.group(1).strip()
            value = match.group(2).strip()
            fields[key] = int(value) if value.isdigit() else value
        elif message is None:
            message = line
        else:
            unrecognized.append(line)

    status = fields.get("签到状态")
    day_count = fields.get("连续签到天数")
    return {
        "message": message,
        "status": status,
        "day_count": day_count,
        "fields": fields,
        "already_checked_in": bool(message == "您已经签到了" or status == "已签到"),
        "unrecognized_lines": unrecognized,
    }


def parse_tree(text):
    """Parse the Thor command tree printed by `bilic tree`.

    Lines look like "  ├─ download_video (download video by bv code)"; the
    output is a single level today, but the depth is computed so a nested tree
    would still be reported correctly.
    """
    root = None
    commands = []

    for raw_line in (text or "").splitlines():
        if not raw_line.strip():
            continue
        match = _BRANCH_RE.match(raw_line)
        if not match:
            if root is None:
                root = raw_line.strip()
            continue

        body = match.group("body").strip()
        name, _, description = body.partition(" (")
        description = description[:-1] if description.endswith(")") else description
        name = name.strip()
        prefix = match.group("prefix")
        depth = prefix.count("│") + 1 if prefix else 1
        commands.append(
            {
                "name": name,
                "description": description.strip(),
                "cli_name": CLI_NAME_ALIASES.get(name, name),
                "depth": depth,
            }
        )

    return {"root": root, "commands": commands, "count": len(commands)}


def parse_login(text):
    """Collect the URL(s) bilic prints while waiting for a QR-code scan."""
    urls = re.findall(r"https?://[^\s\"']+", text or "")
    return {
        "login_urls": urls,
        "output_lines": len([line for line in (text or "").splitlines() if line.strip()]),
    }


def parse_doctor(text):
    """Parse `bilic doctor` output.

    On Linux bilic's doctor is a no-op (its wget/aria2 checks are Windows-only),
    so an empty payload here is the truthful result, not a failure.
    """
    lines = [line.strip() for line in (text or "").splitlines() if line.strip()]
    return {"output_lines": lines, "output_empty": not lines}
