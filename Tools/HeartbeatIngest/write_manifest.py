#!/usr/bin/env python3
"""Write packs/manifest.json from the sqlite files this cook is publishing.

Company bytes are the company seat file's size on disk. Seat entries are
included only for current.sqlite files that exist under the pack root.
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

GRAINS = ("district", "om", "store")
LIST_KEYS = {"district": "districts", "om": "oms", "store": "stores"}


def stamp_from_swift(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    match = re.search(r'static let id = "([^"]+)"', text)
    if not match:
        raise SystemExit(f"No BuildStamp.id in {path}")
    return match.group(1)


def fact_stats(sqlite_path: Path) -> tuple[dict[str, int], int]:
    conn = sqlite3.connect(f"file:{sqlite_path}?mode=ro", uri=True)
    try:
        rows = conn.execute(
            "SELECT section, COUNT(*) FROM facts GROUP BY section"
        ).fetchall()
        store_count = conn.execute(
            """
            SELECT COUNT(DISTINCT store_number) FROM facts
            WHERE TRIM(COALESCE(store_number, '')) != ''
            """
        ).fetchone()[0]
    finally:
        conn.close()
    counts = {str(section): int(count) for section, count in rows}
    return counts, int(store_count or 0)


def seat_entry(grain: str, seat_id: str, sqlite_path: Path) -> dict:
    counts, store_count = fact_stats(sqlite_path)
    return {
        "bytes": sqlite_path.stat().st_size,
        "grain": grain,
        "id": seat_id,
        "path": f"packs/seat/{grain}/{seat_id}/current.sqlite",
        "sectionStoreCounts": counts,
        "storeCount": store_count,
    }


def collect_seats(pack_root: Path) -> dict[str, list[dict]]:
    found = {LIST_KEYS[grain]: [] for grain in GRAINS}
    seat_root = pack_root / "seat"
    if not seat_root.is_dir():
        return found
    for grain in GRAINS:
        grain_root = seat_root / grain
        if not grain_root.is_dir():
            continue
        entries = []
        for sqlite_path in sorted(grain_root.glob("*/current.sqlite")):
            entries.append(seat_entry(grain, sqlite_path.parent.name, sqlite_path))
        entries.sort(key=lambda item: item["id"])
        found[LIST_KEYS[grain]] = entries
    return found


def build_manifest(company_sqlite: Path, pack_root: Path, stamp: str, cooked_at: str) -> dict:
    if not company_sqlite.is_file():
        raise SystemExit(f"Missing company sqlite {company_sqlite}")
    counts, store_count = fact_stats(company_sqlite)
    seats = collect_seats(pack_root)
    return {
        "schema": 1,
        "stamp": stamp,
        "cookedAt": cooked_at,
        "company": {
            "bytes": company_sqlite.stat().st_size,
            "grain": "company",
            "id": "all",
            "path": "packs/seat/company/all/current.sqlite",
            "sectionStoreCounts": counts,
            "storeCount": store_count,
        },
        "districts": seats["districts"],
        "oms": seats["oms"],
        "stores": seats["stores"],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Regenerate packs/manifest.json")
    parser.add_argument("--company", required=True, type=Path)
    parser.add_argument("--pack-root", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--stamp", default="")
    parser.add_argument("--stamp-file", type=Path)
    parser.add_argument("--cooked-at", default="")
    args = parser.parse_args()
    if args.stamp:
        stamp = args.stamp
    elif args.stamp_file:
        stamp = stamp_from_swift(args.stamp_file)
    else:
        raise SystemExit("Pass --stamp or --stamp-file")
    cooked_at = args.cooked_at or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    manifest = build_manifest(args.company, args.pack_root, stamp, cooked_at)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    company_bytes = manifest["company"]["bytes"]
    print(
        f"manifest {args.out} stamp={stamp} company_bytes={company_bytes} "
        f"districts={len(manifest['districts'])} oms={len(manifest['oms'])} "
        f"stores={len(manifest['stores'])}"
    )


if __name__ == "__main__":
    main()
