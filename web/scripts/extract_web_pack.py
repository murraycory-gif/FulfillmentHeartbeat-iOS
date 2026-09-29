#!/usr/bin/env python3
"""Cook a small web pack from the company seat sqlite.

The Pages function does not open sqlite. Run this on the Mac after a cook,
then upload the JSON with wrangler. Do not add this script to the 2-minute
GitHub cook. See web/DEPLOY.md.

Writes:
  <out>/home.json
  <out>/section/<section>.json
  <out>/presub.json
"""

from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path

SECTIONS = (
    "sales",
    "lost_revenue",
    "missing_items",
    "five_star",
    "pre_sub_oos",
    "pick_path",
    "prep_not_ready",
    "dynacap",
    "schedule_quality",
    "pph",
    "labor",
)

# Shopper tape and item tape stay out of the phone browser.
SKIP = {"picker_scorecard", "pre_sub_oos_item", "pick_path_picker", "aisle_mapper"}

KEEP = {
    "sales_dollars",
    "sales_yoy_pct",
    "sales_orders",
    "sales_orders_yoy_pct",
    "sales_aos",
    "sales_aov",
    "sales_aiv",
    "sales_items",
    "sales_ipt",
    "sales_hd_orders",
    "sales_dug_orders",
    "lost_revenue",
    "lost_revenue_pct",
    "ecomm_sales",
    "post_sub_oos_foregone",
    "refund_lost",
    "missed_sales",
    "cancelled_lost",
    "kill_switch_lost",
    "mi_pct",
    "star_rating",
    "flash_pct",
    "coe_pct",
    "ott_pct",
    "presub_pct",
    "oth5_pct",
    "oos_pct",
    "compliance_pct",
    "pph",
    "pnr_rate_pct",
    "prep_not_ready_pct",
    "dynacap_rate",
    "pieces_per_hour",
    "utilization_pct",
    "pickup_util_pct",
    "schedule_efficiency_pct",
    "staffing_efficiency_pct",
    "under_schedule_pct",
    "under_scheduled",
    "over_schedule_pct",
    "over_scheduled",
    "target_vs_actual_pct",
    "act_cost_pct",
    "cost_trgt_pct",
    "uplh_impact_pct",
    "wage_impact_pct",
    "aiv_impact_pct",
}


def canonical_store(raw: str) -> str:
    text = (raw or "").strip()
    if "|" in text:
        text = text.split("|", 1)[0].strip()
    if text.lower().startswith("store"):
        text = text[5:].lstrip(" #")
    digits = ""
    for char in text:
        if char.isdigit():
            digits += char
        else:
            break
    if digits and len(digits) <= 6:
        return str(int(digits))
    return text


def loads(raw: str | None, fallback):
    if not raw:
        return fallback
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return fallback


def slim_payload(raw: str | None) -> dict:
    payload = loads(raw, {})
    if not isinstance(payload, dict):
        return {}
    out = {}
    for key, value in payload.items():
        if key not in KEEP or value is None:
            continue
        if isinstance(value, bool):
            continue
        if isinstance(value, (int, float)):
            out[key] = value
    return out


def extract(sqlite_path: str, out_dir: str) -> None:
    source = Path(sqlite_path)
    if not source.is_file():
        raise SystemExit(f"sqlite not found: {source}")
    out = Path(out_dir)
    section_dir = out / "section"
    section_dir.mkdir(parents=True, exist_ok=True)

    db = sqlite3.connect(f"file:{source}?mode=ro", uri=True)
    db.row_factory = sqlite3.Row
    chrome = {}
    if _table(db, "dash_chrome"):
        row = db.execute("SELECT json FROM dash_chrome WHERE id = 1").fetchone()
        if row:
            parsed = loads(row["json"], {})
            if isinstance(parsed, dict):
                chrome = parsed
    written_at = ""
    meta = db.execute(
        "SELECT written_at FROM pack_meta ORDER BY id LIMIT 1"
    ).fetchone() if _table(db, "pack_meta") else None
    if meta and meta["written_at"]:
        written_at = meta["written_at"]

    latest: dict[tuple[str, str], dict] = {}
    roster: dict[str, dict] = {}
    if _table(db, "facts"):
        query = """
            SELECT section, store_number, division, operations_om, store_name,
                   recorded_on, payload_json, text_json
            FROM facts
        """
        for fact in db.execute(query):
            section = fact["section"] or ""
            if section in SKIP:
                continue
            store = canonical_store(fact["store_number"] or "")
            text = loads(fact["text_json"], {})
            if not isinstance(text, dict):
                text = {}
            district = str(text.get("district") or "")
            record = {
                "store": store,
                "name": fact["store_name"] or "",
                "division": fact["division"] or "",
                "district": district,
                "om": fact["operations_om"] or "",
                "recorded": fact["recorded_on"] or "",
                "payload": slim_payload(fact["payload_json"]),
                "section": section,
            }
            if store:
                _merge_roster(roster, record, prefer_roster=section == "store_roster")
            if section not in SECTIONS or not store:
                continue
            key = (section, store)
            previous = latest.get(key)
            if previous is None or record["recorded"] >= previous["recorded"]:
                latest[key] = record

    presub = {}
    if _table(db, "presub_top"):
        for scope, blob in db.execute("SELECT scope, json FROM presub_top"):
            items = loads(blob, [])
            if isinstance(items, list):
                presub[scope] = items

    published = chrome.get("publishedAt") or written_at or None
    summaries = []
    for item in chrome.get("summaries") or []:
        if not isinstance(item, dict):
            continue
        summaries.append(
            {
                "section": item.get("section"),
                "storeCount": item.get("storeCount"),
                "headline": item.get("headline"),
                "headlineLabel": item.get("headlineLabel") or "",
                "secondary": item.get("secondary") or "",
                "health": item.get("health") or "none",
                "watchCount": item.get("watchCount") or 0,
                "riskCount": item.get("riskCount") or 0,
            }
        )
    home = {
        "publishedAt": published,
        "summaries": summaries,
        "companyTiles": chrome.get("companyTiles") or {},
        "pickerRollups": chrome.get("pickerRollups") or {},
        "preSubItemTabPresent": chrome.get("preSubItemTabPresent"),
        "filters": {
            "stores": sorted(roster.values(), key=lambda item: (len(item["store"]), item["store"])),
        },
    }
    _write(out / "home.json", home)
    grouped: dict[str, list] = {section: [] for section in SECTIONS}
    for record in latest.values():
        grouped[record["section"]].append(
            {
                "store": record["store"],
                "name": record["name"],
                "division": record["division"],
                "district": record["district"],
                "om": record["om"],
                "payload": record["payload"],
            }
        )
    for section, rows in grouped.items():
        rows.sort(key=lambda item: (len(item["store"]), item["store"]))
        _write(section_dir / f"{section}.json", {"section": section, "rows": rows})
    _write(out / "presub.json", {"scopes": presub})
    db.close()


def _merge_roster(roster: dict, record: dict, prefer_roster: bool) -> None:
    current = roster.get(record["store"])
    if current is None:
        roster[record["store"]] = {
            "store": record["store"],
            "division": record["division"],
            "district": record["district"],
            "om": record["om"],
            "name": record["name"],
        }
        return
    if prefer_roster:
        for field in ("division", "district", "om", "name"):
            if record[field]:
                current[field] = record[field]
        return
    for field in ("division", "district", "om", "name"):
        if not current[field] and record[field]:
            current[field] = record[field]


def _table(db: sqlite3.Connection, name: str) -> bool:
    row = db.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
        (name,),
    ).fetchone()
    return row is not None


def _write(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, separators=(",", ":"), ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_web_pack.py <company-seat.sqlite> <out-dir>")
    extract(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    main()
