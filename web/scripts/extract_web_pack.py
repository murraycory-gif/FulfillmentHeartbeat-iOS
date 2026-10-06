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
    "lost_revenue_goal",
    "lost_revenue_goal_pct",
    "ecomm_sales",
    "post_sub_oos_foregone",
    "refund_lost",
    "missed_sales",
    "reduced_capacity",
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
    "eot_capacity",
    "used_capacity",
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
    "jewel": "Jewel Osco",
    "jewelosco": "Jewel Osco",
    "nocal": "NorCal",
    "northerncalifornia": "NorCal",
    "norcalifornia": "NorCal",
    "southerncalifornia": "SoCal",
    "socalifornia": "SoCal",
    "southerncal": "SoCal",
    "mountainwest": "Mountain West",
    "denver": "Mountain West",
    "intermountain": "Mountain West",
    "unitedtexas": "United",
    "unitedsupermarkets": "United",
}

# Short region names used on the cooked region lines.
_DIVISION_REGION = {
    "Shaws": "East",
    "Mid-Atlantic": "East",
    "Jewel Osco": "East",
    "Southern": "South",
    "United": "South",
    "Southwest": "South",
    "NorCal": "California",
    "SoCal": "California",
    "Mountain West": "West",
    "Seattle": "West",
    "Haggen": "West",
    "Portland": "West",
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


def is_total_store(store: str) -> bool:
    """Excel total rows are not stores. Counting them double-counts the company."""
    return str(store or "").strip().upper() == "TOTAL"


# South is 397 schedule stores. The older device list stopped at 395 and left out
# store 210 (United, district U5, Andrew Quinn) and store 239 (Southwest, district N0, Ben Sarmadi).
# Both stay on the site roster.


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


def _money_label(value: float) -> str:
    return f"${value:,.2f}"


def percent_points(sample, dollars, sales):
    """5.19 means 5.19%. Scale a fraction (0.0519) only when it matches dollars/sales."""
    stored = None if sample is None else float(sample)
    ratio = None
    if sales and float(sales) > 0 and dollars is not None and float(dollars) != 0:
        ratio = float(dollars) / float(sales)
    scaled = None if ratio is None else ratio * 100
    if stored is None:
        return scaled
    if ratio is not None and abs(stored) <= 1.5 and abs(ratio - stored) <= abs(scaled - stored):
        return scaled
    return stored


def lost_market_payload(db: sqlite3.Connection) -> dict:
    if not _table(db, "facts"):
        return {}
    for fact in db.execute(
        "SELECT payload_json, text_json FROM facts WHERE section = 'lost_revenue'"
    ):
        text = loads(fact["text_json"], {})
        if isinstance(text, dict) and text.get("lost_grain") == "market":
            payload = loads(fact["payload_json"], {})
            return payload if isinstance(payload, dict) else {}
    return {}


def labor_market_payload(db: sqlite3.Connection) -> dict:
    if not _table(db, "facts"):
        return {}
    for fact in db.execute(
        "SELECT payload_json, text_json FROM facts WHERE section = 'labor' AND store_number = 'TOTAL'"
    ):
        text = loads(fact["text_json"], {})
        if isinstance(text, dict) and text.get("labor_grain") == "market":
            payload = loads(fact["payload_json"], {})
            return payload if isinstance(payload, dict) else {}
    return {}


def company_aiv_percent(value: float) -> float:
    """The only ×100. Total AIV is a fraction. Store rows are already percent points."""
    if value != 0 and abs(value) < 0.05:
        return value * 100
    return value


def format_company_aiv(value: float) -> str:
    """Print percent points. Scaling stays in company_aiv_percent."""
    return f"{float(value):.2f}%"


def apply_labor_aiv_tile(tiles: dict, market: dict) -> None:
    """Company AIV is the Labor workbook Total scaled once from a fraction to percent points.

    The stored Total 0.0026109 is a fraction. ×100 once is about 0.26%. Store rows stay as cooked.
    """
    block = tiles.get("labor")
    if not isinstance(block, dict) or not market:
        return
    raw = market.get("aiv_impact_pct")
    if raw is None:
        return
    try:
        number = company_aiv_percent(float(raw))
    except (TypeError, ValueError):
        return
    labels = list(block.get("labels") or [])
    values = list(block.get("values") or [])
    if "AIV" not in labels:
        return
    index = labels.index("AIV")
    if index < len(values):
        values[index] = format_company_aiv(number)
        block["values"] = values


def apply_lost_tile_scale(tiles: dict, market: dict) -> None:
    """Company Lost % / Goal % are fractions printed with a % sign. Missed is reduced capacity when that is the only dollar."""
    block = tiles.get("lost_revenue")
    if not isinstance(block, dict) or not market:
        return
    labels = list(block.get("labels") or [])
    values = list(block.get("values") or [])
    if not labels:
        return

    def put(name: str, text: str | None) -> None:
        if text is None or name not in labels:
            return
        index = labels.index(name)
        if index < len(values):
            values[index] = text

    lost = market.get("lost_revenue")
    sales = market.get("ecomm_sales")
    points = percent_points(market.get("lost_revenue_pct"), lost, sales)
    if points is not None:
        put("Lost %", f"{points:.2f}%")
    goal_points = percent_points(market.get("lost_revenue_goal_pct"), market.get("lost_revenue_goal"), sales)
    if goal_points is not None:
        put("Goal %", f"{goal_points:.2f}%")
    missed = market.get("missed_sales")
    if missed is None:
        missed = market.get("reduced_capacity")
    if missed is not None:
        put("Missed", _money_label(float(missed)))
    block["values"] = values


CALLOUT_ORDER = (
    "sales",
    "lost_revenue",
    "missing_items",
    "five_star",
    "pre_sub_oos",
    "pick_path",
    "prep_not_ready",
    "dynacap",
    "schedule_quality",
    "picker_scorecard",
    "pph",
    "labor",
)

CALLOUT_TITLE = {
    "sales": "Sales",
    "lost_revenue": "Lost Revenue",
    "missing_items": "Missing Items",
    "five_star": "5 Star",
    "pre_sub_oos": "Pre-Sub",
    "pick_path": "Pick Path",
    "prep_not_ready": "Prep",
    "dynacap": "Dynacap",
    "schedule_quality": "Schedule Quality",
    "picker_scorecard": "Picker",
    "pph": "PPH",
    "labor": "Labor",
}


def region_tables(tables) -> list:
    """One headline per callout, grouped later by region. Not the metric-first line list."""
    if not isinstance(tables, dict):
        return []
    rows = []
    for section in CALLOUT_ORDER:
        for item in tables.get(section) or []:
            if not isinstance(item, dict):
                continue
            region = short_region(str(item.get("label") or ""))
            if region not in REGION_RANK:
                continue
            values = item.get("values") or []
            headline = values[0] if values else None
            if headline is None or str(headline).strip() == "":
                continue
            try:
                count = int(item.get("storeCount") or 0)
            except (TypeError, ValueError):
                count = 0
            rows.append(
                {
                    "section": section,
                    "region": region,
                    "title": CALLOUT_TITLE[section],
                    "health": item.get("health") or "none",
                    "storeCount": count,
                    "headline": str(headline),
                }
            )
    return rows


def include_unrated_dynacap(lines: list, records: list) -> list:
    """United has store rows and no Pcs/Hr. Show the division with a blank rate. Do not invent one, and do not touch Mid-Atlantic."""
    counts: dict[str, int] = {}
    for record in records:
        if record.get("section") != "dynacap":
            continue
        payload = record.get("payload") or {}
        if payload.get("dynacap_rate") is not None or payload.get("pieces_per_hour") is not None:
            continue
        division = canonical_division(record.get("division") or "")
        region = _DIVISION_REGION.get(division)
        if not division or not region:
            continue
        counts[division] = counts.get(division, 0) + 1
    if not counts:
        return lines
    for line in lines:
        if line.get("section") != "dynacap":
            continue
        present = {child.get("division") for child in line.get("children") or []}
        for division in OFFICIAL_DIVISIONS:
            count = counts.get(division)
            if not count or division in present:
                continue
            if _DIVISION_REGION.get(division) != line.get("region"):
                continue
            line.setdefault("children", []).append(
                {
                    "division": division,
                    "value": "—",
                    "count": count,
                    "health": "none",
                }
            )
    return lines


def realign_lost_revenue(lines: list, records: list) -> list:
    """Lost-revenue facts stamp every store as Haggen. Recount from the roster division."""
    buckets: dict[str, dict[str, dict]] = {}
    for record in records:
        if record.get("section") != "lost_revenue":
            continue
        store = record.get("store") or ""
        if is_total_store(store):
            continue
        division = canonical_division(record.get("division") or "")
        region = _DIVISION_REGION.get(division)
        if not region:
            continue
        payload = record.get("payload") or {}
        try:
            amount = float(payload.get("lost_revenue") or 0)
        except (TypeError, ValueError):
            amount = 0.0
        slot = buckets.setdefault(region, {}).setdefault(division, {"sum": 0.0, "count": 0})
        slot["sum"] += amount
        slot["count"] += 1
    if not buckets:
        return lines
    previous = {item.get("region"): item for item in lines if item.get("section") == "lost_revenue"}
    rebuilt = []
    for region in ("East", "South", "California", "West"):
        divisions = buckets.get(region)
        if not divisions:
            continue
        prior = previous.get(region) or {}
        old_health = {
            child.get("division"): child.get("health") or "none" for child in prior.get("children") or []
        }
        children = []
        total = 0.0
        count = 0
        for division in OFFICIAL_DIVISIONS:
            slot = divisions.get(division)
            if not slot:
                continue
            total += slot["sum"]
            count += slot["count"]
            children.append(
                {
                    "division": division,
                    "value": _money_label(slot["sum"]),
                    "count": slot["count"],
                    "health": old_health.get(division) or "none",
                }
            )
        rebuilt.append(
            {
                "section": "lost_revenue",
                "region": region,
                "title": prior.get("title") or LINE_TITLE["lost_revenue"],
                "value": _money_label(total),
                "count": count,
                "health": prior.get("health") or "none",
                "children": children,
            }
        )
    if not rebuilt:
        return lines
    out = []
    seen = set()
    by_region = {item["region"]: item for item in rebuilt}
    for item in lines:
        if item.get("section") != "lost_revenue":
            out.append(item)
            continue
        region = item.get("region")
        if region in by_region and region not in seen:
            out.append(by_region[region])
            seen.add(region)
    for item in rebuilt:
        if item["region"] not in seen:
            out.append(item)
    return out


def schedule_summary_title(title: str, week) -> str:
    """The workbook title can lag a week. The pack week is the one on the file."""
    text = title or ""
    try:
        cooked = int(week)
    except (TypeError, ValueError):
        return text
    if cooked <= 0:
        return text
    text = re.sub(r"Week\s*\d+", f"Week {cooked}", text, flags=re.I)
    return re.sub(r"WK\s*\d+", f"WK{cooked}", text, flags=re.I)


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
        "summaryTitle": schedule_summary_title(row["summary_title"] or "", row["week"] or 0),
        "workbookActionBanner": row["workbook_action_banner"],
        "markets": markets,
        "stores": stores,
    }


def _blank_schedule_artifact(store: dict) -> bool:
    """Stores Current Week left under/over blank. Detail INDEX of a blank is 0, and eff 1 is not 100%."""
    if store.get("under") not in (0, 0.0) or store.get("over") not in (0, 0.0):
        return False
    if store.get("eff") not in (100, 100.0):
        return False
    if store.get("pch") is not None or store.get("fourUnder") is not None or store.get("fourOver") is not None:
        return False
    if any(value is not None for value in (store.get("dayUnder") or [])):
        return False
    if any(value is not None for value in (store.get("dayOver") or [])):
        return False
    return True


def clear_blank_schedule(schedule: dict) -> None:
    for store in schedule.get("stores") or []:
        if isinstance(store, dict) and _blank_schedule_artifact(store):
            store["under"] = None
            store["over"] = None
            store["eff"] = None
    for market in schedule.get("markets") or []:
        if not isinstance(market, dict):
            continue
        if market.get("under") is None and market.get("over") is None and market.get("eff") in (100, 100.0, 1, 1.0):
            market["eff"] = None


def _fill_schedule_roster(schedule: dict, roster: dict) -> None:
    """Schedule rows with a blank OM take the store roster person."""
    for store in schedule.get("stores") or []:
        if not isinstance(store, dict):
            continue
        key = canonical_store(str(store.get("store") or ""))
        current = roster.get(key)
        if not current:
            continue
        if current.get("om"):
            store["om"] = current["om"]
        if not store.get("district") and current.get("district"):
            store["district"] = current["district"]
        if current.get("division"):
            store["division"] = current["division"]


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
            if not store or is_total_store(store):
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
        if is_total_store(store):
            continue
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
            if is_total_store(store):
                continue
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
                # Lost-revenue facts tag every store Haggen. Keep the store, not that division.
                if section == "lost_revenue":
                    seeded = dict(record)
                    seeded["division"] = ""
                    _merge_roster(roster, seeded, prefer_roster=False)
                else:
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
    for item in roster.values():
        item["division"] = canonical_division(item.get("division") or "")
    # Division belongs to the store. The roster wins over a sheet that mis-tags the row.
    for record in records:
        current = roster.get(record["store"])
        if current and current.get("division"):
            record["division"] = current["division"]
        elif record.get("division"):
            record["division"] = canonical_division(record["division"])
        if not current:
            continue
        for field in ("district", "om"):
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
    company_tiles = json.loads(json.dumps(chrome.get("companyTiles") or {}))
    apply_lost_tile_scale(company_tiles, lost_market_payload(db))
    labor_market = labor_market_payload(db)
    apply_labor_aiv_tile(company_tiles, labor_market)
    labor_aiv = labor_market.get("aiv_impact_pct")
    if labor_aiv is not None:
        try:
            labor_aiv = company_aiv_percent(float(labor_aiv))
        except (TypeError, ValueError):
            labor_aiv = None
    home = {
        "publishedAt": published,
        "summaries": summaries,
        "companyTiles": company_tiles,
        "laborMarket": {"aiv_impact_pct": labor_aiv} if labor_aiv is not None else {},
        "pickerRollups": chrome.get("pickerRollups") or {},
        "preSubItemTabPresent": item_tab,
        "filters": {
            "stores": sorted(
                (
                    item
                    for item in roster.values()
                    if not is_total_store(item["store"])
                ),
                key=lambda item: (len(item["store"]), item["store"]),
            ),
        },
        "regionLines": include_unrated_dynacap(
            realign_lost_revenue(region_lines(chrome.get("packs") or {}), records),
            records,
        ),
        "regionTables": region_tables(chrome.get("tables") or {}),
    }
    _write(out / "home.json", home)
    schedule = read_schedule(db) or read_schedule_file(source.parent / "schedule-check.json")
    schedule_path = out / "schedule.json"
    if schedule:
        _fill_schedule_roster(schedule, roster)
        clear_blank_schedule(schedule)
        schedule["summaryTitle"] = schedule_summary_title(schedule.get("summaryTitle") or "", schedule.get("week") or 0)
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
