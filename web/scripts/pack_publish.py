#!/usr/bin/env python3
"""Upload one cook to a new R2 prefix, then move web-pack/current.json last.

The live prefix and the fallback prefix are never written. A re-cook of the
same cookSha keeps the pack it replaces as previous instead of clearing it.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

PINNED_LIVE_COOK_SHA = "74d44dde02a0e1c6430a9a78b06034099c84e001"
PINNED_LIVE_PUBLISHED_AT = "2026-10-06T01:35:23Z"


def pointer_entry(old: dict) -> dict:
    sha = str(old.get("cookSha") or "")
    published = str(old.get("publishedAt") or "")
    cooked = str(old.get("cookedAt") or "")
    prefix = str(old.get("prefix") or f"web-pack/{sha}-{published}")
    pinned = sha == PINNED_LIVE_COOK_SHA and published == PINNED_LIVE_PUBLISHED_AT and not cooked
    if not cooked and not pinned:
        raise SystemExit("data-only upload: pack has no cookedAt")
    return {
        "prefix": prefix,
        "cookSha": sha,
        "publishedAt": published,
        "cookedAt": cooked,
        "schemaVersion": old.get("schemaVersion"),
    }


def plan_pointer(old: dict, sha: str, cooked: str, published: str, schema) -> dict:
    if not cooked or "/" in cooked or "\\" in cooked:
        raise SystemExit("data-only upload: cookedAt missing")
    if cooked == published:
        raise SystemExit("data-only upload: cookedAt must not copy publishedAt")
    prefix = f"web-pack/{sha}-{cooked}"
    live_prefix = str(old.get("prefix") or "")
    if live_prefix and live_prefix == prefix:
        raise SystemExit("data-only upload: refusing to write into the live pack folder")
    previous_obj = old.get("previous") if isinstance(old.get("previous"), dict) else None
    fallback_prefix = str((previous_obj or {}).get("prefix") or "")
    if fallback_prefix and fallback_prefix == prefix:
        raise SystemExit("data-only upload: refusing to write into the fallback pack folder")
    previous = None
    old_sha = str(old.get("cookSha") or "")
    if re.fullmatch(r"[0-9a-f]{40}", old_sha) and live_prefix and live_prefix != prefix:
        previous = pointer_entry(old)
    elif previous_obj:
        previous = pointer_entry(previous_obj)
    return {
        "prefix": prefix,
        "cookSha": sha,
        "cookedAt": cooked,
        "publishedAt": published,
        "schemaVersion": schema,
        "previous": previous,
    }


def upload_pack(root: Path, check_pack: Path, wrangler=None, checker=None) -> dict:
    def run(args, check=True):
        if wrangler is not None:
            return wrangler(args, check=check)
        return subprocess.run(["npx", "wrangler", *args], check=check)

    files = sorted(path for path in root.rglob("*.json") if path.is_file())
    if not files:
        raise SystemExit("data-only upload: no pack json")
    home_path = root / "home.json"
    if not home_path.is_file():
        raise SystemExit("data-only upload: home.json is missing")
    home = json.loads(home_path.read_text(encoding="utf-8"))
    meta = home.get("metadata") if isinstance(home.get("metadata"), dict) else {}
    sha = str(meta.get("cookSha") or home.get("cookSha") or "")
    published = str(home.get("publishedAt") or "")
    cooked = str(home.get("cookedAt") or meta.get("cookedAt") or "")
    schema = home.get("schemaVersion")
    if schema is None:
        schema = meta.get("schemaVersion")
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise SystemExit("data-only upload: cookSha missing")
    if not published or "/" in published or "\\" in published:
        raise SystemExit("data-only upload: publishedAt missing")

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        pointer_file = tmp_path / "current.json"
        got = run(
            ["r2", "object", "get", "heartbeat-packs/web-pack/current.json", f"--file={pointer_file}", "--remote"],
            check=False,
        )
        old = {}
        if getattr(got, "returncode", 1) == 0 and pointer_file.is_file():
            try:
                loaded = json.loads(pointer_file.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                loaded = {}
            if isinstance(loaded, dict):
                old = loaded
        plan = plan_pointer(old, sha, cooked, published, schema)
        prefix = plan["prefix"]
        for path in files:
            rel = path.relative_to(root).as_posix()
            key = f"heartbeat-packs/{prefix}/{rel}"
            run(["r2", "object", "put", key, f"--file={path}", "--remote"])
        downloaded = tmp_path / "uploaded"
        for path in files:
            rel = path.relative_to(root).as_posix()
            dest = downloaded / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            key = f"heartbeat-packs/{prefix}/{rel}"
            run(["r2", "object", "get", key, f"--file={dest}", "--remote"])
        if checker is not None:
            checked = checker(downloaded)
        else:
            checked = subprocess.run(["node", str(check_pack), str(downloaded)], check=False)
        if getattr(checked, "returncode", 1) != 0:
            raise SystemExit("data-only upload: check_pack failed on the uploaded set; current.json was not moved")
        next_pointer = tmp_path / "next-current.json"
        next_pointer.write_text(json.dumps(plan), encoding="utf-8")
        run(["r2", "object", "put", "heartbeat-packs/web-pack/current.json", f"--file={next_pointer}", "--remote"])
    print(
        f"data-only upload: {len(files)} pack files at {plan['prefix']}/, check_pack passed, current.json updated, site tree not deployed"
    )
    return plan


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: pack_publish.py DATA_DIR check_pack.mjs", file=sys.stderr)
        return 2
    upload_pack(Path(sys.argv[1]), Path(sys.argv[2]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
