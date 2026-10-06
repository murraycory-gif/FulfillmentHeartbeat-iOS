#!/usr/bin/env python3
"""Choose a pack by cookSha + cookedAt. publishedAt is the workbook time and is not a newer-than key.

Every JSON file in one directory must agree. A pack with no cookedAt is never
published, including the live cook 74d44dde02a0e1c6430a9a78b06034099c84e001.
The site may keep serving that cook. An extract with no cookedAt does not
replace a pack that already has one.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def _stamp(payload: dict) -> tuple[str, str]:
    meta = payload.get("metadata") if isinstance(payload.get("metadata"), dict) else {}
    sha = str(payload.get("cookSha") or meta.get("cookSha") or "")
    cooked = str(payload.get("cookedAt") or meta.get("cookedAt") or "")
    return sha, cooked


def load_identity(root: Path) -> dict:
    """Return cookSha and cookedAt when every JSON file agrees. Otherwise errors."""
    if not root.is_dir():
        return {"cookSha": "", "cookedAt": "", "errors": [f"{root} is missing"]}
    files = sorted(path for path in root.rglob("*.json") if path.is_file())
    if not files:
        return {"cookSha": "", "cookedAt": "", "errors": [f"{root} has no json"]}
    expected: tuple[str, str] | None = None
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
            errors.append(f"{path.relative_to(root).as_posix()} cookSha/cookedAt does not match the rest of the pack")
    if errors or expected is None:
        return {"cookSha": "", "cookedAt": "", "errors": errors or ["pack identity missing"]}
    return {"cookSha": expected[0], "cookedAt": expected[1], "errors": []}


def identity_of(payload: dict) -> dict:
    sha, cooked = _stamp(payload if isinstance(payload, dict) else {})
    return {"cookSha": sha, "cookedAt": cooked, "errors": [] if sha else ["cookSha missing"]}


def prefer(fresh: dict, have: dict | None) -> str:
    """replace, keep, or refuse. fresh is the new extract. have is the pack already on disk."""
    if fresh.get("errors"):
        return "refuse"
    fresh_at = str(fresh.get("cookedAt") or "")
    fresh_sha = str(fresh.get("cookSha") or "")
    if not fresh_sha:
        return "refuse"
    if have is None:
        return "replace" if fresh_at else "refuse"
    if have.get("errors"):
        return "refuse"
    have_at = str(have.get("cookedAt") or "")
    have_sha = str(have.get("cookSha") or "")
    if not have_sha:
        return "refuse"
    if not fresh_at:
        return "refuse" if not have_at else "keep"
    if not have_at:
        return "replace"
    if fresh_at == have_at:
        return "keep" if fresh_sha == have_sha else "refuse"
    return "replace" if fresh_at > have_at else "keep"


def newer(live: dict, local: dict) -> str:
    """fetch, keep, or refuse. live is the site home. local is the pack on disk."""
    if live.get("errors") or local.get("errors"):
        return "refuse"
    live_at = str(live.get("cookedAt") or "")
    local_at = str(local.get("cookedAt") or "")
    live_sha = str(live.get("cookSha") or "")
    local_sha = str(local.get("cookSha") or "")
    if not live_sha or not local_sha:
        return "refuse"
    if not live_at and not local_at:
        return "refuse"
    if live_at and not local_at:
        return "fetch"
    if local_at and not live_at:
        return "keep"
    if live_at == local_at:
        return "keep" if live_sha == local_sha else "refuse"
    return "fetch" if live_at > local_at else "keep"


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
        print(f"cookSha={found['cookSha']} cookedAt={found['cookedAt'] or 'missing'}")
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
        decision = newer(identity_of(live_payload), load_identity(local_path))
        print(decision)
        return 0 if decision in {"fetch", "keep"} else 1
    print(f"unknown command {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
