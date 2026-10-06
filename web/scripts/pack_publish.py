#!/usr/bin/env python3
"""Upload one cook to a new R2 prefix, then move web-pack/current.json last.

The live prefix and the fallback prefix are never written. A re-cook of the
same cookSha keeps the pack it replaces as previous instead of clearing it.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

PINNED_LIVE_COOK_SHA = "74d44dde02a0e1c6430a9a78b06034099c84e001"
PINNED_LIVE_PUBLISHED_AT = "2026-10-06T01:35:23Z"
PINNED_LIVE_PREFIX = f"web-pack/{PINNED_LIVE_COOK_SHA}-{PINNED_LIVE_PUBLISHED_AT}"
PINNED_HOME_SHA256 = "fece0ad52e54aa5cb3cb7a3637552d831a4e276d28b695ca3b2797172f7d839a"
POINTER_KEY = "heartbeat-packs/web-pack/current.json"


def pointer_entry(old: dict) -> dict:
    sha = str(old.get("cookSha") or "")
    published = str(old.get("publishedAt") or "")
    cooked = str(old.get("cookedAt") or "")
    prefix = str(old.get("prefix") or f"web-pack/{sha}-{published}")
    pinned = (
        sha == PINNED_LIVE_COOK_SHA
        and published == PINNED_LIVE_PUBLISHED_AT
        and not cooked
        and prefix == PINNED_LIVE_PREFIX
    )
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


def _run(wrangler, args, check=True):
    if wrangler is not None:
        return wrangler(args, check=check)
    return subprocess.run(["npx", "wrangler", *args], check=check)


def _remote_bytes(run, key: str, dest: Path):
    if dest.exists():
        dest.unlink()
    got = run(["r2", "object", "get", key, f"--file={dest}", "--remote"], check=False)
    code = getattr(got, "returncode", 1)
    if code != 0:
        if dest.is_file() and dest.stat().st_size > 0:
            raise SystemExit(f"pointer preflight: {key} get failed")
        return None
    if not dest.is_file():
        raise SystemExit(f"pointer preflight: {key} get wrote nothing")
    return dest.read_bytes()


def pointer_servable(old: dict) -> bool:
    sha = str(old.get("cookSha") or "")
    published = str(old.get("publishedAt") or "")
    cooked = str(old.get("cookedAt") or "")
    prefix = str(old.get("prefix") or "")
    if not re.fullmatch(r"[0-9a-f]{40}", sha) or old.get("schemaVersion") != 1:
        return False
    if not prefix.startswith("web-pack/") or ".." in prefix or "\\" in prefix:
        return False
    if cooked:
        if "/" in cooked or "\\" in cooked or not published:
            return False
        return prefix == f"web-pack/{sha}-{cooked}"
    return sha == PINNED_LIVE_COOK_SHA and published == PINNED_LIVE_PUBLISHED_AT and prefix == PINNED_LIVE_PREFIX


def _migrate_pinned_pointer(run, tmp_path: Path) -> str:
    home_key = f"heartbeat-packs/{PINNED_LIVE_PREFIX}/home.json"
    raw = _remote_bytes(run, home_key, tmp_path / "home.json")
    if raw is None:
        raise SystemExit("pointer preflight: pinned home.json is missing")
    digest = hashlib.sha256(raw).hexdigest()
    if digest != PINNED_HOME_SHA256:
        raise SystemExit("pointer preflight: pinned home.json sha256 does not match")
    pointer = {
        "prefix": PINNED_LIVE_PREFIX,
        "cookSha": PINNED_LIVE_COOK_SHA,
        "publishedAt": PINNED_LIVE_PUBLISHED_AT,
        "cookedAt": "",
        "schemaVersion": 1,
    }
    dest = tmp_path / "next-current.json"
    dest.write_text(json.dumps(pointer), encoding="utf-8")
    run(["r2", "object", "put", POINTER_KEY, f"--file={dest}", "--remote"])
    print("pointer preflight: migrated pinned pointer")
    return "migrated"


def preflight_pointer(root: Path, wrangler=None) -> str:
    """Verify current.json, or write the pinned pointer when it is absent.

    Absent means the get failed and wrote no object. Empty or corrupt JSON
    is not absent. A cookedAt pack, or the pinned prefix, is verified with
    no put. Any other pointer is refused with no put.
    """
    if not root.is_dir():
        raise SystemExit("pointer preflight: data dir is missing")

    def run(args, check=True):
        return _run(wrangler, args, check=check)

    with tempfile.TemporaryDirectory() as tmp:
        raw = _remote_bytes(run, POINTER_KEY, Path(tmp) / "current.json")
        if raw is None:
            return _migrate_pinned_pointer(run, Path(tmp))
        text = raw.decode("utf-8")
        if not text.strip():
            raise SystemExit("pointer preflight: current.json is empty")
        try:
            loaded = json.loads(text)
        except json.JSONDecodeError:
            raise SystemExit("pointer preflight: current.json is not json")
        if not isinstance(loaded, dict):
            raise SystemExit("pointer preflight: current.json is not an object")
        if pointer_servable(loaded):
            print("pointer preflight: verified")
            return "verified"
        raise SystemExit("pointer preflight: current.json is not a cooked pack or the pinned live pack")


def main() -> int:
    if len(sys.argv) >= 2 and sys.argv[1] == "preflight":
        if len(sys.argv) != 3:
            print("usage: pack_publish.py preflight DATA_DIR", file=sys.stderr)
            return 2
        preflight_pointer(Path(sys.argv[2]))
        return 0
    if len(sys.argv) != 3:
        print("usage: pack_publish.py DATA_DIR check_pack.mjs | preflight DATA_DIR", file=sys.stderr)
        return 2
    upload_pack(Path(sys.argv[1]), Path(sys.argv[2]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
