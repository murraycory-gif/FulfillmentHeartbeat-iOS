#!/usr/bin/env python3
"""Choose a pack by cookSha + cookedAt. publishedAt is the workbook time and is not a newer-than key.

Every JSON file in one directory must agree. A pack with no cookedAt is never
published. The site may still serve the live cook pinned in pack-store.js
(cookSha 74d44dde02a0e1c6430a9a78b06034099c84e001, publishedAt 2026-10-06T01:35:23Z).
A later live cookedAt is fetched only when that cookSha is HEAD or an ancestor.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

PINNED_LIVE_COOK_SHA = "74d44dde02a0e1c6430a9a78b06034099c84e001"
PINNED_LIVE_PUBLISHED_AT = "2026-10-06T01:35:23Z"
ROOT = Path(__file__).resolve().parents[2]


def _stamp(payload: dict) -> tuple[str, str, str]:
    meta = payload.get("metadata") if isinstance(payload.get("metadata"), dict) else {}
    sha = str(payload.get("cookSha") or meta.get("cookSha") or "")
    cooked = str(payload.get("cookedAt") or meta.get("cookedAt") or "")
    published = str(payload.get("publishedAt") or meta.get("publishedAt") or "")
    return sha, cooked, published


def _blank(errors: list[str]) -> dict:
    return {"cookSha": "", "cookedAt": "", "publishedAt": "", "errors": errors}


def load_identity(root: Path) -> dict:
    """Return cookSha, cookedAt, and publishedAt when every JSON file agrees."""
    if not root.is_dir():
        return _blank([f"{root} is missing"])
    files = sorted(path for path in root.rglob("*.json") if path.is_file())
    if not files:
        return _blank([f"{root} has no json"])
    expected: tuple[str, str, str] | None = None
    errors: list[str] = []
    for path in files:
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            errors.append(f"{path.name} is not json")
            continue
        if not isinstance(payload, dict):
            errors.append(f"{path.name} is not an object")
            continue
        stamp = _stamp(payload)
        if not stamp[0]:
            errors.append(f"{path.relative_to(root).as_posix()} cookSha missing")
        if expected is None:
            expected = stamp
        elif stamp != expected:
            errors.append(
                f"{path.relative_to(root).as_posix()} cookSha/cookedAt/publishedAt does not match the rest of the pack"
            )
    if errors or expected is None:
        return _blank(errors or ["pack identity missing"])
    return {"cookSha": expected[0], "cookedAt": expected[1], "publishedAt": expected[2], "errors": []}


def identity_of(payload: dict) -> dict:
    body = payload if isinstance(payload, dict) else {}
    sha, cooked, published = _stamp(body)
    return {
        "cookSha": sha,
        "cookedAt": cooked,
        "publishedAt": published,
        "errors": [] if sha else ["cookSha missing"],
    }


def is_pinned_live(item: dict | None) -> bool:
    if not item:
        return False
    return (
        str(item.get("cookSha") or "") == PINNED_LIVE_COOK_SHA
        and str(item.get("publishedAt") or "") == PINNED_LIVE_PUBLISHED_AT
        and not str(item.get("cookedAt") or "")
    )


def prefer(fresh: dict, have: dict | None) -> str:
    """replace, keep, or refuse. fresh is the new extract. have is the pack already on disk."""
    if fresh.get("errors"):
        return "refuse"
    fresh_at = str(fresh.get("cookedAt") or "")
    fresh_sha = str(fresh.get("cookSha") or "")
    if not fresh_sha or not fresh_at:
        return "refuse"
    if have is None:
        return "replace"
    if have.get("errors"):
        return "refuse"
    have_at = str(have.get("cookedAt") or "")
    have_sha = str(have.get("cookSha") or "")
    # The committed pack is the pinned cookedAt-less identity. A fresh cook
    # may replace that one pack. Any other disk pack with no cookedAt stays refused.
    if not have_at and is_pinned_live(have):
        return "replace"
    if not have_sha or not have_at:
        return "refuse"
    if fresh_at == have_at:
        return "keep" if fresh_sha == have_sha else "refuse"
    return "replace" if fresh_at > have_at else "keep"


def newer(live: dict, local: dict, ancestor_ok=None) -> str:
    """fetch, keep, or refuse. live is the site home. local is the pack on disk.

    ancestor_ok(cookSha) is true when that commit is HEAD or an ancestor of HEAD.
    A later live cookedAt is refused when the callback is missing or false.
    """
    if live.get("errors") or local.get("errors"):
        return "refuse"
    live_at = str(live.get("cookedAt") or "")
    local_at = str(local.get("cookedAt") or "")
    live_sha = str(live.get("cookSha") or "")
    local_sha = str(local.get("cookSha") or "")
    if not live_sha or not local_sha:
        return "refuse"
    if is_pinned_live(live) and local_at:
        return "keep"
    if not live_at or not local_at:
        return "refuse"
    if live_at == local_at:
        return "keep" if live_sha == local_sha else "refuse"
    if live_at > local_at:
        if ancestor_ok is None or not ancestor_ok(live_sha):
            return "refuse"
        return "fetch"
    return "keep"


def commit_is_ancestor(sha: str, root: Path = ROOT) -> bool:
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        return False
    proc = subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", sha, "HEAD"],
        capture_output=True,
    )
    return proc.returncode == 0


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: pack_identity.py check DIR | prefer FRESH HAVE | newer LIVE.json LOCAL", file=sys.stderr)
        return 2
    command = sys.argv[1]
    if command == "check":
        found = load_identity(Path(sys.argv[2]))
        if found["errors"]:
            print("\n".join(found["errors"]), file=sys.stderr)
            return 1
        print(
            f"cookSha={found['cookSha']} cookedAt={found['cookedAt'] or 'missing'} publishedAt={found['publishedAt']}"
        )
        return 0
    if command == "prefer":
        fresh_path = Path(sys.argv[2])
        have_path = Path(sys.argv[3])
        fresh = load_identity(fresh_path)
        have = load_identity(have_path) if have_path.exists() else None
        decision = prefer(fresh, have)
        print(decision)
        return 0 if decision in {"replace", "keep"} else 1
    if command == "newer":
        live_path = Path(sys.argv[2])
        local_path = Path(sys.argv[3])
        try:
            live_payload = json.loads(live_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            print("refuse")
            return 1
        decision = newer(identity_of(live_payload), load_identity(local_path), commit_is_ancestor)
        print(decision)
        return 0 if decision in {"fetch", "keep"} else 1
    print(f"unknown command {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
