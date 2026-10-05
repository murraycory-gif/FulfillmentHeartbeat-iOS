#!/usr/bin/env python3
"""Cook a small web pack from the company seat sqlite.

The Pages function does not open sqlite. Run this on the Mac after a cook,
then upload the JSON with wrangler. Do not add this script to the 2-minute
GitHub cook. See web/DEPLOY.md.

Writes:
  <out>/home.json
  <out>/section/<section>.json
  <out>/presub.json
  <out>/schedule.json   only when the sqlite (or a sibling schedule-check.json) has rows
"""

from __future__ import annotations

import json
import re
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

# Item tape stays out of the phone browser. Shopper rows are exported.
SKIP = {"pre_sub_oos_item", "aisle_mapper"}
SHOPPER_SECTIONS = {"picker_scorecard", "pick_path_picker"}

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
    "pick_hours",
    "orders",
    "subs",
}


OFFICIAL_DIVISIONS = (
    "Shaws",
    "Mid-Atlantic",
    "Jewel Osco",
    "Southern",
    "United",
    "Southwest",
    "NorCal",
    "SoCal",
    "Mountain West",
    "Seattle",
    "Haggen",
    "Portland",
)

_DIVISION_ALIAS = {
    "midatlantic": "Mid-Atlantic",
    "jewelosco": "Jewel Osco",
    "nocal": "NorCal",
    "northerncalifornia": "NorCal",
    "norcalifornia": "NorCal",
    "southerncalifornia": "SoCal",
    "socalifornia": "SoCal",
    "southerncal": "SoCal",
    "mountainwest": "Mountain West",
    "unitedtexas": "United",
    "unitedsupermarkets": "United",
}
for _name in OFFICIAL_DIVISIONS:
    _DIVISION_ALIAS["".join(ch for ch in _name.lower() if ch.isalnum())] = _name


def canonical_division(raw: str) -> str:
    text = (raw or "").strip()
    if not text:
        return ""
    if text in OFFICIAL_DIVISIONS:
        return text
    key = "".join(ch for ch in text.lower() if ch.isalnum())
    if key.startswith("united"):
        return "United"
    return _DIVISION_ALIAS.get(key, text)


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


LINE_ORDER = (
    "pre_sub_oos",
    "missing_items",
    "lost_revenue",
    "pph",
    "prep_not_ready",
    "sales",
    "picker_scorecard",
    "five_star",
    "pick_path",
    "dynacap",
    "schedule_quality",
    "labor",
)

LINE_TITLE = {
    "pre_sub_oos": "Pre-Sub",
    "missing_items": "Missing",
    "lost_revenue": "Loss",
    "pph": "PPH",
    "prep_not_ready": "Prep",
    "sales": "Sales",
    "picker_scorecard": "Pickers",
    "five_star": "5 Star",
    "pick_path": "Pick Path",
    "dynacap": "Dynacap",
    "schedule_quality": "Schedule Quality",
    "labor": "Labor",
}

REGION_RANK = {"East": 0, "South": 1, "California": 2, "West": 3}


def short_region(label: str) -> str:
    text = (label or "").strip()
    if text.lower().endswith(" region"):
        text = text[: -len(" region")].strip()
    return text


def region_lines(packs) -> list:
    """Region scope lines only. Division children stay off this table."""
    if not isinstance(packs, dict):
        return []
    lines = []
    for section in LINE_ORDER:
        items = packs.get(section) or []
        if not isinstance(items, list):
            continue
        found = []
        for item in items:
            if not isinstance(item, dict):
                continue
            line = item.get("line") or {}
            if not isinstance(line, dict):
                continue
            region = short_region(str(line.get("label") or ""))
            if region not in REGION_RANK:
                continue
            value = line.get("value")
            if value is None or str(value).strip() in {"", "—", "-", "–"}:
                continue
            try:
                count = int(line.get("count") or 0)
            except (TypeError, ValueError):
                count = 0
            children = []
            for child in item.get("children") or []:
                if not isinstance(child, dict):
                    continue
                label = str(child.get("label") or "").strip()
                child_value = child.get("value")
                if not label or child_value is None or str(child_value).strip() in {"", "—", "-", "–"}:
                    continue
                try:
                    child_count = int(child.get("count") or 0)
                except (TypeError, ValueError):
                    child_count = 0
                children.append(
                    {
                        "division": label,
                        "value": str(child_value),
                        "count": child_count,
                        "health": child.get("health") or "none",
                    }
                )
            found.append(
                {
                    "section": section,
                    "region": region,
                    "title": LINE_TITLE[section],
                    "value": str(value),
                    "count": count,
                    "health": line.get("health") or "none",
                    "children": children,
                }
            )
        found.sort(key=lambda item: REGION_RANK[item["region"]])
        lines.extend(found)
    return lines


def read_schedule(db: sqlite3.Connection) -> dict | None:
    if not _table(db, "schedule_pack"):
        return None
    row = db.execute(
        """
        SELECT published_at, week, filename, summary_title, workbook_action_banner
        FROM schedule_pack WHERE id = 1
        """
    ).fetchone()
    if row is None:
        return None
    markets = []
    if _table(db, "schedule_market"):
        for market in db.execute("SELECT label, under, over, eff FROM schedule_market ORDER BY label"):
            markets.append(
                {
                    "label": market["label"] or "",
                    "under": market["under"],
                    "over": market["over"],
                    "eff": market["eff"],
                }
            )
    stores = []
    if _table(db, "schedule_store"):
        query = """
            SELECT store, region, division, district, om, sales, under, over, eff, pch,
                   four_under, four_over, star, day_under_json, day_over_json
            FROM schedule_store
            ORDER BY CAST(store AS INTEGER), store
        """
        for store in db.execute(query):
            stores.append(
                {
                    "store": store["store"] or "",
                    "region": store["region"] or "",
                    "division": store["division"] or "",
                    "district": store["district"] or "",
                    "om": store["om"] or "",
                    "sales": store["sales"],
                    "under": store["under"],
                    "over": store["over"],
                    "eff": store["eff"],
                    "pch": store["pch"],
                    "fourUnder": store["four_under"],
                    "fourOver": store["four_over"],
                    "star": store["star"],
                    "dayUnder": loads(store["day_under_json"], []),
                    "dayOver": loads(store["day_over_json"], []),
                }
            )
    if not markets and not stores:
        return None
    return {
        "publishedAt": row["published_at"] or "",
        "week": row["week"] or 0,
        "filename": row["filename"] or "",
        "summaryTitle": row["summary_title"] or "",
        "workbookActionBanner": row["workbook_action_banner"],
        "markets": markets,
        "stores": stores,
    }


def read_schedule_file(path: Path) -> dict | None:
    if not path.is_file():
        return None
    parsed = loads(path.read_text(encoding="utf-8"), None)
    if not isinstance(parsed, dict):
        return None
    stores = parsed.get("stores")
    markets = parsed.get("markets")
    if not isinstance(stores, list):
        stores = []
    if not isinstance(markets, list):
        markets = []
    if not stores and not markets:
        return None
    return parsed


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


def is_person_om(raw: str) -> bool:
    name = " ".join(str(raw or "").split())
    if not name or any(ch.isdigit() for ch in name):
        return False
    tokens = [token for token in re.split(r"[\s/]+", name) if any(ch.isalpha() for ch in token)]
    return len(tokens) >= 2


def read_roster_people(path: str) -> dict:
    """Daily Roster: OM_ID is the person. OM_AREA is the area and is not the OM."""
    import openpyxl

    workbook = openpyxl.load_workbook(path, read_only=True, data_only=True)
    try:
        if "Roster" not in workbook.sheetnames:
            return {}
        sheet = workbook["Roster"]
        people: dict[str, dict] = {}
        division = ""
        district = ""
        om = ""
        started = False
        for row in sheet.iter_rows(values_only=True):
            cells = [("" if value is None else str(value).strip()) for value in list(row)[:5]]
            while len(cells) < 5:
                cells.append("")
            if not started:
                header = [cell.lower().replace(" ", "").replace("_", "") for cell in cells]
                if "omid" in header:
                    started = True
                continue
            div, dist, _area, om_raw, store_raw = cells
            if div and div.lower() != "total" and div.upper() != "WEEK_ID":
                division = canonical_division(div)
            if dist and dist.lower() != "total":
                district = dist
            if om_raw and om_raw.lower() != "total":
                om = om_raw if is_person_om(om_raw) else ""
            if not store_raw or store_raw.lower() == "total":
                continue
            store = canonical_store(store_raw)
            if not store:
                continue
            people[store] = {
                "division": division,
                "district": district,
                "om": om if is_person_om(om) else "",
            }
        return people
    finally:
        workbook.close()


def apply_roster_people(roster: dict, records: list, people: dict) -> dict:
    """Stamp person OM names onto the store list and every fact for that store."""
    named = 0
    for store, ident in people.items():
        person = ident.get("om") or ""
        if person:
            named += 1
        current = roster.get(store)
        if current is None:
            roster[store] = {
                "store": store,
                "division": ident.get("division") or "",
                "district": ident.get("district") or "",
                "om": person,
                "name": "",
            }
        else:
            if ident.get("division"):
                current["division"] = ident["division"]
            if ident.get("district"):
                current["district"] = ident["district"]
            current["om"] = person
    known = set(people)
    for record in records:
        ident = people.get(record["store"])
        if ident:
            if ident.get("division"):
                record["division"] = ident["division"]
            if ident.get("district"):
                record["district"] = ident["district"]
            record["om"] = ident.get("om") or ""
        else:
            # The Daily roster is the OM source. A stray section name is not a seat.
            record["om"] = ""
    for current in roster.values():
        if current["store"] not in known:
            current["om"] = ""
    return {"stores": len(people), "named": named}


def extract(sqlite_path: str, out_dir: str, roster_xlsx: str | None = None) -> None:
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
    shoppers: dict[tuple[str, str, str], dict] = {}
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
                "division": canonical_division(fact["division"] or ""),
                "district": district,
                "om": fact["operations_om"] or "",
                "recorded": fact["recorded_on"] or "",
                "payload": slim_payload(fact["payload_json"]),
                "section": section,
            }
            if section in SHOPPER_SECTIONS:
                # Path Picker rows have no store until the scorecard join below.
                if not store and section != "pick_path_picker":
                    continue
                shopper_id = str(text.get("shopper_id") or "").strip()
                shopper_name = str(text.get("shopper_name") or shopper_id).strip()
                record["shopper"] = shopper_name
                record["shopperId"] = shopper_id
                if store:
                    _merge_roster(roster, record, prefer_roster=False)
                identity = shopper_id or shopper_name
                if not identity:
                    continue
                key = (section, store, identity)
                previous = shoppers.get(key)
                if previous is None or record["recorded"] >= previous["recorded"]:
                    shoppers[key] = record
                continue
            if store:
                _merge_roster(roster, record, prefer_roster=section == "store_roster")
            if section not in SECTIONS or not store:
                continue
            key = (section, store)
            previous = latest.get(key)
            if previous is None or record["recorded"] >= previous["recorded"]:
                latest[key] = record
    # Path Picker is an employee sheet with no store column. Attach the
    # scorecard store only when that shopper id is on exactly one store.
    attach_unique_scorecard_store(shoppers)
    for record in shoppers.values():
        if record.get("section") == "pick_path_picker" and record.get("store"):
            _merge_roster(roster, record, prefer_roster=False)
    records = list(latest.values()) + list(shoppers.values())
    people = read_roster_people(roster_xlsx) if roster_xlsx else {}
    if people:
        stats = apply_roster_people(roster, records, people)
        print(
            f"roster people: {stats['named']} named of {stats['stores']} stores"
            f" ({len({item['om'] for item in people.values() if item.get('om')})} names)"
        )
    # A section row with a blank seat inherits the store list. It does not invent one.
    for record in records:
        current = roster.get(record["store"])
        if not current:
            continue
        for field in ("division", "district", "om"):
            if not record.get(field) and current.get(field):
                record[field] = current[field]

    presub = {}
    if _table(db, "presub_top"):
        for scope, blob in db.execute("SELECT scope, json FROM presub_top"):
            items = loads(blob, [])
            if isinstance(items, list):
                presub[scope] = items

    published = chrome.get("publishedAt") or written_at or None
    item_tab = _item_tab_present(db, chrome)
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
        "preSubItemTabPresent": item_tab,
        "filters": {
            "stores": sorted(roster.values(), key=lambda item: (len(item["store"]), item["store"])),
        },
        "regionLines": region_lines(chrome.get("packs") or {}),
    }
    _write(out / "home.json", home)
    schedule = read_schedule(db) or read_schedule_file(source.parent / "schedule-check.json")
    schedule_path = out / "schedule.json"
    if schedule:
        _write(schedule_path, schedule)
    else:
        # Keep the URL as JSON. An older file must not keep stores this pack lacks.
        _write(schedule_path, empty_schedule())
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
    shopper_grouped: dict[str, list] = {section: [] for section in SHOPPER_SECTIONS}
    for record in shoppers.values():
        shopper_grouped[record["section"]].append(
            {
                "store": record["store"],
                "name": record["name"],
                "division": record["division"],
                "district": record["district"],
                "om": record["om"],
                "shopper": record.get("shopper") or "",
                "shopperId": record.get("shopperId") or "",
                "payload": record["payload"],
            }
        )
    for section, rows in shopper_grouped.items():
        rows.sort(key=lambda item: (len(item["store"]), item["store"], item.get("shopper") or ""))
        _write(section_dir / f"{section}.json", {"section": section, "rows": rows})
    _write(out / "presub.json", {"scopes": presub})
    db.close()


def attach_unique_scorecard_store(shoppers: dict) -> int:
    by_shopper: dict[str, set[str]] = {}
    for record in shoppers.values():
        if record.get("section") != "picker_scorecard":
            continue
        shopper_id = str(record.get("shopperId") or "").strip()
        store = str(record.get("store") or "").strip()
        if shopper_id and store:
            by_shopper.setdefault(shopper_id, set()).add(store)
    attached = 0
    for record in shoppers.values():
        if record.get("section") != "pick_path_picker":
            continue
        if str(record.get("store") or "").strip():
            continue
        shopper_id = str(record.get("shopperId") or "").strip()
        options = by_shopper.get(shopper_id) or set()
        if len(options) != 1:
            continue
        record["store"] = next(iter(options))
        attached += 1
    return attached


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


def empty_schedule() -> dict:
    return {
        "publishedAt": "",
        "week": 0,
        "filename": "",
        "summaryTitle": "",
        "workbookActionBanner": None,
        "markets": [],
        "stores": [],
        "empty": True,
    }


def _item_tab_present(db: sqlite3.Connection, chrome: dict) -> bool:
    """Cooked chrome wins when it says so. Otherwise only a real item tab counts."""
    explicit = chrome.get("preSubItemTabPresent")
    if isinstance(explicit, bool):
        return explicit
    if _table(db, "presub_top") and db.execute("SELECT 1 FROM presub_top LIMIT 1").fetchone():
        return True
    if _table(db, "facts") and db.execute(
        "SELECT 1 FROM facts WHERE section = ? LIMIT 1",
        ("pre_sub_oos_item",),
    ).fetchone():
        return True
    return False


def _table(db: sqlite3.Connection, name: str) -> bool:
    row = db.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
        (name,),
    ).fetchone()
    return row is not None


def _write(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, separators=(",", ":"), ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    if len(sys.argv) not in (3, 4):
        raise SystemExit("usage: extract_web_pack.py <company-seat.sqlite> <out-dir> [daily-roster.xlsx]")
    extract(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) == 4 else None)


if __name__ == "__main__":
    main()
