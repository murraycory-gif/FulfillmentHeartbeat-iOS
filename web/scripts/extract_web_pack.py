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
import os
import re
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
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
    "act_cost_dollars",
    "cost_trgt_pct",
    "uplh_impact_pct",
    "wage_impact_pct",
    "aiv_impact_pct",
    "sch_hrs",
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


def roster_division(record: dict, roster: dict) -> str:
    """Display division for a fact. Roster name first, then the sheet token."""
    current = roster.get(record.get("store") or "")
    if current and current.get("division"):
        named = canonical_division(current.get("division") or "")
        if named:
            return named
    return canonical_division(record.get("division") or "")


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
# Both stay on the site roster. The Loss Revenue sheet stamps every store Haggen, including these two.
SHEET_LOSS_IDENTITY = {
    "210": {"division": "United", "district": "U5", "om": "Andrew Quinn"},
    "239": {"division": "Southwest", "district": "N0", "om": "Ben Sarmadi"},
}
# Daily Loss Revenue store rows, excluding the Total row and the filter footer.
LOSS_SHEET_STORE_COUNT = 2167


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
    """Legacy chrome reader. The cook builds lines with build_region_views."""
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
                raw_label = str(child.get("label") or "").strip()
                label = canonical_division(raw_label) or raw_label
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


def format_company_aiv(value: float) -> str:
    """Percent points, same unit as the store rows. 0.0026109 prints as 0.00%."""
    return f"{float(value):.2f}%"


# Blank cells stay null. A real 0 is a measurement and is not a blank.
LABOR_BLANK_NULLS = ("act_cost_pct", "act_hrs", "act_cost_dollars", "cost_trgt_pct")


def labor_blank_number(raw: dict, key: str):
    """None when the cell is missing or blank. Zero stays zero."""
    names = ("act_cost_dollars", "act_cost_dollar") if key == "act_cost_dollars" else (key,)
    seen = False
    value = None
    for name in names:
        if isinstance(raw, dict) and name in raw:
            seen = True
            value = raw.get(name)
            break
    if not seen or value is None:
        return None
    if isinstance(value, str):
        if not value.strip():
            return None
        try:
            value = float(value)
        except ValueError:
            return None
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    if value != value or value in (float("inf"), float("-inf")):
        return None
    return value


def apply_labor_blanks(payload: dict, raw: dict) -> None:
    """Store 866's blank ActCost% cooked as 0. A blank is null, the same for ActHrs, ActCost$, and CostTrgt%."""
    if not isinstance(payload, dict):
        return
    for key in LABOR_BLANK_NULLS:
        payload[key] = labor_blank_number(raw, key)


def labor_act_hours(raw: dict) -> float | None:
    """Labor!E is actual hours. The company ActHrs cell is the sum of that column.

    Company AIV (Labor!M2171) matches the ActHrs-weighted average of store rows
    that have a cost target. A simple average does not: stores 233 and 1509
    dominate it. Sales dollars do not reproduce M2171.
    """
    if not isinstance(raw, dict):
        return None
    try:
        hours = float(raw.get("act_hrs"))
    except (TypeError, ValueError):
        return None
    if hours < 0 or hours != hours or hours == float("inf"):
        return None
    return hours


def labor_bridge(payload: dict) -> dict:
    """Company AIV is the workbook Total. The company object has no weight field."""
    out = {}
    for key in ("uplh_impact_pct", "wage_impact_pct", "aiv_impact_pct", "target_vs_actual_pct"):
        raw = payload.get(key)
        if raw is None:
            continue
        try:
            out[key] = float(raw)
        except (TypeError, ValueError):
            continue
    return out


def apply_labor_aiv_tile(tiles: dict, market: dict) -> None:
    """Print the Labor Total AIV. Do not scale it again and do not average the stores."""
    block = tiles.get("labor")
    if not isinstance(block, dict) or not market:
        return
    raw = market.get("aiv_impact_pct")
    if raw is None:
        return
    try:
        number = float(raw)
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


def labor_source_issue(payload: dict) -> bool:
    """Bad Labor source rows stay in the pack, flagged instead of read as a real AIV.

    Cost target blank and UPLH/Wage/AIV/Act Cost/Target vs Actual the same magnitude
    (UPLH carries the opposite sign). Or scheduled hours are 0.
    """
    if not isinstance(payload, dict):
        return False
    scheduled = payload.get("sch_hrs")
    if scheduled is not None:
        try:
            if float(scheduled) == 0:
                return True
        except (TypeError, ValueError):
            pass
    if payload.get("cost_trgt_pct") is not None:
        return False
    keys = (
        "uplh_impact_pct",
        "wage_impact_pct",
        "aiv_impact_pct",
        "act_cost_pct",
        "target_vs_actual_pct",
    )
    magnitudes = []
    for key in keys:
        raw = payload.get(key)
        if raw is None:
            return False
        try:
            magnitudes.append(abs(float(raw)))
        except (TypeError, ValueError):
            return False
    return max(magnitudes) - min(magnitudes) <= 0.01


def apply_lost_tile_scale(tiles: dict, market: dict) -> None:
    """Company Lost % / Goal % are fractions printed with a % sign. Missed is missed_sales dollars, never reduced capacity."""
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
    if missed is not None:
        put("Missed", _money_label(float(missed)))
    block["values"] = values


def apply_workbook_missed(tiles: dict, workbook_total: dict | None) -> None:
    """Company Missed is Loss Revenue column V on the Total row, via home.workbookTotal."""
    if not isinstance(workbook_total, dict):
        return
    lost = workbook_total.get("lost_revenue")
    if not isinstance(lost, dict) or lost.get("missed_dollars") is None:
        return
    block = tiles.get("lost_revenue")
    if not isinstance(block, dict):
        return
    text = _money_label(float(lost["missed_dollars"]))
    labels = list(block.get("labels") or [])
    values = list(block.get("values") or [])
    if "Missed" in labels:
        index = labels.index("Missed")
        while len(values) <= index:
            values.append("")
        values[index] = text
    else:
        labels.append("Missed")
        values.append(text)
    block["labels"] = labels
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
    """Legacy chrome reader. The cook builds tables with build_region_views."""
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


LOST_EXCL_TITLE = "Lost $ excl. Missed"
OWN_STORE_SECTIONS = ("lost_revenue", "missing_items", "five_star", "pre_sub_oos")


def _number_or_zero(payload: dict, key: str) -> float:
    if not isinstance(payload, dict):
        return 0.0
    raw = payload.get(key)
    if raw is None or raw == "":
        return 0.0
    try:
        number = float(raw)
    except (TypeError, ValueError):
        return 0.0
    if number != number or number in (float("inf"), float("-inf")):
        return 0.0
    return number


def realign_lost_revenue(lines: list, records: list) -> list:
    """Lost $ excl. Missed is lost_revenue minus missed_sales on this section's rows.

    A missing missed_sales is 0. Company Lost $ and Missed $ stay on the workbook
    tiles. Region, division, and district do not sum missed_sales.
    """
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
        amount = _number_or_zero(payload, "lost_revenue") - _number_or_zero(payload, "missed_sales")
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
                    "missed": "Not available",
                }
            )
        rebuilt.append(
            {
                "section": "lost_revenue",
                "region": region,
                "title": LOST_EXCL_TITLE,
                "value": _money_label(total),
                "count": count,
                "health": prior.get("health") or "none",
                "missed": "Not available",
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


def sync_lost_region_tables(tables: list, lines: list) -> None:
    """Region cards copy the section roll-up, including stores the old chrome omitted."""
    by_region = {
        item.get("region"): item
        for item in lines
        if isinstance(item, dict) and item.get("section") == "lost_revenue" and item.get("title") == LOST_EXCL_TITLE
    }
    if not by_region:
        return
    for row in tables:
        if not isinstance(row, dict) or row.get("section") != "lost_revenue":
            continue
        line = by_region.get(row.get("region"))
        if not line:
            continue
        row["headline"] = line.get("value")
        row["storeCount"] = line.get("count") or 0
        row["title"] = LOST_EXCL_TITLE


def _first_number(payload, keys):
    if not isinstance(payload, dict):
        return None
    for key in keys:
        raw = payload.get(key)
        if raw is None or raw == "":
            continue
        try:
            number = float(raw)
        except (TypeError, ValueError):
            continue
        if number != number or number in (float("inf"), float("-inf")):
            continue
        return number
    return None


def _band(value, good, watch, invert=False) -> str:
    if value is None:
        return "none"
    if invert:
        if value <= good:
            return "good"
        if value <= watch:
            return "watch"
        return "risk"
    if value >= good:
        return "good"
    if value >= watch:
        return "watch"
    return "risk"


# Same cutoffs as the web seat. The cooked line and the card badge agree.
_SCOPE_RULES = {
    "missing_items": (5, 6.5, True),
    "pre_sub_oos": (5, 6.5, True),
    "five_star": (4, 3.5, False),
    "pick_path": (90, 80, False),
    "prep_not_ready": (1.9, 2.5, True),
    "dynacap": (65, 60, False),
    "schedule_quality": (90, 85, False),
    "pph": (80, 74, False),
    "labor": (0, 3, True),
    "picker_scorecard": (80, 74, False),
}

_RATE_FIELDS = {
    "missing_items": ("mi_pct",),
    "pre_sub_oos": ("oos_pct", "mi_pct"),
    "five_star": ("star_rating",),
    "pick_path": ("compliance_pct",),
    "prep_not_ready": ("pnr_rate_pct", "prep_not_ready_pct"),
    "dynacap": ("dynacap_rate", "pieces_per_hour"),
    "schedule_quality": ("schedule_efficiency_pct",),
    "pph": ("pph",),
    "labor": ("target_vs_actual_pct",),
}

_TONE_RANK = {"none": 0, "good": 1, "watch": 2, "risk": 3}


def _scope_health(section: str, headline) -> str:
    rule = _SCOPE_RULES.get(section)
    if not rule or headline is None:
        return "none"
    try:
        number = float(headline)
    except (TypeError, ValueError):
        return "none"
    if number != number:
        return "none"
    good, watch, invert = rule
    return _band(number, good, watch, invert)


def _sales_yoy(rows) -> float | None:
    this_year = 0.0
    last_year = 0.0
    for row in rows:
        payload = row.get("payload") or {}
        current = _first_number(payload, ("sales_dollars",))
        yoy = _first_number(payload, ("sales_yoy_pct",))
        if current is None or current <= 0 or yoy is None or yoy <= -100 or abs(yoy) >= 1000:
            continue
        factor = 1 + yoy / 100
        if not factor > 0:
            continue
        prior = current / factor
        if not prior > 0:
            continue
        this_year += current
        last_year += prior
    if not (last_year > 0 and this_year > 0):
        return None
    return (this_year / last_year - 1) * 100


def _sales_health(yoy) -> str:
    if yoy is None:
        return "none"
    if yoy > 0:
        return "good"
    if yoy >= -3:
        return "watch"
    return "risk"


def _rate_label(section: str, value: float) -> str:
    if section == "five_star":
        return f"{value:.2f}"
    if section in ("pph", "dynacap"):
        return f"{value:.1f}"
    return f"{value:.2f}%"


def _shopper_identity(record: dict) -> str:
    raw = str(record.get("shopperId") or record.get("shopper") or "").strip().lower()
    return "".join(ch for ch in raw if ch.isalnum())


def _region_of(record: dict) -> str:
    return _DIVISION_REGION.get(canonical_division(record.get("division") or ""), "")


def _scope_figure(section: str, rows: list) -> dict | None:
    if section == "sales":
        scored = [
            row
            for row in rows
            if _first_number(row.get("payload") or {}, ("sales_dollars",)) is not None
        ]
        if not scored:
            return None
        dollars = sum(_first_number(row.get("payload") or {}, ("sales_dollars",)) or 0 for row in scored)
        return {
            "value": _money_label(dollars),
            "count": len(scored),
            "health": _sales_health(_sales_yoy(scored)),
        }
    if section == "picker_scorecard":
        seen = set()
        pphs = []
        for row in rows:
            ident = _shopper_identity(row)
            if ident:
                seen.add(ident)
            pph = _first_number(row.get("payload") or {}, ("pph",))
            if pph is not None:
                pphs.append(pph)
        if not seen:
            return None
        mean = sum(pphs) / len(pphs) if pphs else None
        return {
            "value": f"{len(seen)} shoppers",
            "count": len(seen),
            "health": _scope_health("picker_scorecard", mean),
        }
    fields = _RATE_FIELDS.get(section)
    if not fields:
        return None
    values = []
    for row in rows:
        number = _first_number(row.get("payload") or {}, fields)
        if number is not None:
            values.append(number)
    if not values:
        return None
    average = sum(values) / len(values)
    return {
        "value": _rate_label(section, average),
        "count": len(values),
        "health": _scope_health(section, average),
    }


def _region_lines_from_rows(records: list) -> list:
    """Region and division figures from this cook's store rows."""
    grouped: dict[str, dict[str, dict[str, list]]] = {}
    for record in records:
        section = record.get("section") or ""
        if section not in LINE_TITLE or section == "lost_revenue":
            continue
        store = str(record.get("store") or "")
        if is_total_store(store):
            continue
        if section == "labor" and (record.get("sourceIssue") or labor_source_issue(record.get("payload") or {})):
            continue
        region = _region_of(record)
        division = canonical_division(record.get("division") or "")
        if not region or not division:
            continue
        grouped.setdefault(section, {}).setdefault(region, {}).setdefault(division, []).append(record)
    lines = []
    for section in LINE_ORDER:
        if section == "lost_revenue":
            continue
        found = []
        for region in ("East", "South", "California", "West"):
            divisions = (grouped.get(section) or {}).get(region) or {}
            children = []
            region_rows = []
            for division in OFFICIAL_DIVISIONS:
                bucket = divisions.get(division) or []
                if not bucket:
                    continue
                figure = _scope_figure(section, bucket)
                if figure is None:
                    continue
                region_rows.extend(bucket)
                children.append({"division": division, **figure})
            if not children:
                continue
            parent = _scope_figure(section, region_rows)
            if parent is None:
                continue
            found.append(
                {
                    "section": section,
                    "region": region,
                    "title": LINE_TITLE[section],
                    **parent,
                    "children": children,
                }
            )
        lines.extend(found)
    return lines


def _region_tables_from_lines(lines: list) -> list:
    index = {
        (item.get("section"), item.get("region")): item
        for item in lines
        if isinstance(item, dict)
    }
    rows = []
    for section in CALLOUT_ORDER:
        for region in ("East", "South", "California", "West"):
            line = index.get((section, region))
            if not line:
                continue
            headline = line.get("value")
            if section == "picker_scorecard":
                try:
                    headline = f"{int(line.get('count') or 0):,}"
                except (TypeError, ValueError):
                    headline = line.get("value")
            if headline is None or str(headline).strip() in {"", "—", "-", "–"}:
                continue
            title = line.get("title") if section == "lost_revenue" else CALLOUT_TITLE[section]
            try:
                count = int(line.get("count") or 0)
            except (TypeError, ValueError):
                count = 0
            rows.append(
                {
                    "section": section,
                    "region": region,
                    "title": title,
                    "health": line.get("health") or "none",
                    "storeCount": count,
                    "headline": str(headline),
                }
            )
    return rows


def build_region_views(records: list) -> tuple[list, list]:
    """Region lines and region tables from roster store rows.

    Money and store counts are sums. Picker counts are distinct shoppers.
    Rates are unweighted store averages. Lost $ excl. Missed is lost minus missed.
    """
    lines = include_unrated_dynacap(
        realign_lost_revenue(_region_lines_from_rows(records), records),
        records,
    )
    return lines, _region_tables_from_lines(lines)


def _star_health(value, full, half, invert) -> str:
    if invert:
        if value < full:
            return "good"
        if value <= half:
            return "watch"
        return "risk"
    if value >= full:
        return "good"
    if value >= half:
        return "watch"
    return "risk"


def _picker_has_volume(payload) -> bool:
    for key in ("orders", "picks", "pick_hours"):
        number = _first_number(payload, (key,))
        if number is not None and number > 0:
            return True
    return _first_number(payload, ("pph",)) is not None


def _picker_status_tone(record: dict) -> str:
    payload = record.get("payload") or {}
    flags = []
    pph = _first_number(payload, ("pph",))
    if pph is not None:
        flags.append(_band(pph, 80, 74))
    presub = _first_number(payload, ("presub_pct",))
    if presub is not None:
        flags.append(_star_health(presub, 5, 6, True))
    oos = _first_number(payload, ("oos_pct",))
    if oos is not None:
        flags.append(_star_health(oos, 3, 5, True))
    oth = _first_number(payload, ("oth5_pct",))
    if oth is not None:
        flags.append(_star_health(oth, 92, 78, False))
    coe = _first_number(payload, ("coe_pct",))
    if coe is not None:
        flags.append(_star_health(coe, 20, 0, False))
    ott = _first_number(payload, ("ott_pct",))
    if ott is not None:
        flags.append(_star_health(ott, 95, 90, False))
    if "risk" in flags:
        health = "risk"
    elif "watch" in flags:
        health = "watch"
    elif "good" in flags:
        health = "good"
    else:
        health = "none"
    if health == "none" and _picker_has_volume(payload):
        return "watch"
    return health


def build_picker_rollups(records: list) -> dict:
    """Distinct shoppers and stores for company, region, division, district, OM, and store."""
    buckets: dict[str, dict] = {}

    def add(scope: str, ident: str, store: str, tone: str) -> None:
        if not scope or not ident:
            return
        slot = buckets.setdefault(scope, {"tones": {}, "stores": set()})
        previous = slot["tones"].get(ident)
        if previous is None or _TONE_RANK[tone] > _TONE_RANK[previous]:
            slot["tones"][ident] = tone
        if store:
            slot["stores"].add(store)

    for record in records:
        if record.get("section") != "picker_scorecard":
            continue
        store = str(record.get("store") or "").strip()
        if not store or is_total_store(store):
            continue
        ident = _shopper_identity(record)
        if not ident:
            continue
        tone = _picker_status_tone(record)
        if tone == "none":
            tone = "watch"
        add("company", ident, store, tone)
        region = _region_of(record)
        if region:
            add(f"region:{region} Region", ident, store, tone)
        division = canonical_division(record.get("division") or "")
        if division:
            add(f"division:{division}", ident, store, tone)
        district = str(record.get("district") or "").strip()
        if district:
            add(f"district:{district}", ident, store, tone)
        om = str(record.get("om") or "").strip()
        if om:
            add(f"om:{om}", ident, store, tone)
        add(f"store:{store}", ident, store, tone)
    out = {}
    for scope, slot in buckets.items():
        tones = list(slot["tones"].values())
        if not tones:
            continue
        out[scope] = {
            "shoppers": len(tones),
            "stores": len(slot["stores"]),
            "healthy": sum(tone == "good" for tone in tones),
            "watch": sum(tone == "watch" for tone in tones),
            "risk": sum(tone == "risk" for tone in tones),
        }
    return out


def _parse_money(text) -> float | None:
    if not isinstance(text, str):
        return None
    cleaned = text.replace("$", "").replace(",", "").strip()
    if cleaned in {"", "—", "-", "–"}:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def _close(left: float, right: float, tolerance: float = 0.05) -> bool:
    return abs(left - right) <= tolerance


def assert_additive_region_sums(lines: list, records: list, workbook_total: dict | None = None) -> None:
    """Region money and store counts add up to the company total for additive metrics."""
    _assert_sales_regions(lines, records, workbook_total)
    _assert_lost_regions(lines, records)


def _assert_sales_regions(lines: list, records: list, workbook_total: dict | None) -> None:
    scoped = [line for line in lines if line.get("section") == "sales"]
    region_sum = 0.0
    region_count = 0
    for line in scoped:
        money = _parse_money(str(line.get("value") or ""))
        if money is None:
            raise SystemExit(f"sales region {line.get('region')} has no dollars")
        count = int(line.get("count") or 0)
        child_sum = 0.0
        child_count = 0
        for child in line.get("children") or []:
            child_money = _parse_money(str(child.get("value") or ""))
            if child_money is None:
                raise SystemExit(f"sales {line.get('region')} {child.get('division')} has no dollars")
            child_sum += child_money
            child_count += int(child.get("count") or 0)
        if not _close(child_sum, money):
            raise SystemExit(f"sales {line.get('region')} divisions ${child_sum:,.2f} != region ${money:,.2f}")
        if child_count != count:
            raise SystemExit(f"sales {line.get('region')} division stores {child_count} != {count}")
        region_sum += money
        region_count += count
    store_sum = 0.0
    store_count = 0
    orphan = 0.0
    for record in records:
        if record.get("section") != "sales" or is_total_store(record.get("store") or ""):
            continue
        dollars = _first_number(record.get("payload") or {}, ("sales_dollars",))
        if dollars is None:
            continue
        if not _region_of(record):
            orphan += float(dollars)
            continue
        store_sum += float(dollars)
        store_count += 1
    if abs(orphan) > 0.02:
        raise SystemExit(f"sales outside a region ${orphan:,.2f}")
    if not _close(region_sum, store_sum):
        raise SystemExit(f"sales regions ${region_sum:,.2f} != stores ${store_sum:,.2f}")
    if region_count != store_count:
        raise SystemExit(f"sales region stores {region_count} != {store_count}")
    company = None
    if isinstance(workbook_total, dict):
        sales = workbook_total.get("sales")
        if isinstance(sales, dict) and sales.get("sales_dollars") is not None:
            company = float(sales["sales_dollars"])
    if company is not None and store_count and not _close(region_sum, company):
        raise SystemExit(f"sales regions ${region_sum:,.2f} != workbook ${company:,.2f}")


def _assert_lost_regions(lines: list, records: list) -> None:
    scoped = [line for line in lines if line.get("section") == "lost_revenue"]
    region_sum = 0.0
    region_count = 0
    for line in scoped:
        money = _parse_money(str(line.get("value") or ""))
        if money is None:
            raise SystemExit(f"lost region {line.get('region')} has no dollars")
        count = int(line.get("count") or 0)
        child_sum = 0.0
        child_count = 0
        for child in line.get("children") or []:
            child_money = _parse_money(str(child.get("value") or ""))
            if child_money is None:
                raise SystemExit(f"lost {line.get('region')} {child.get('division')} has no dollars")
            child_sum += child_money
            child_count += int(child.get("count") or 0)
        if not _close(child_sum, money):
            raise SystemExit(f"lost {line.get('region')} divisions ${child_sum:,.2f} != region ${money:,.2f}")
        if child_count != count:
            raise SystemExit(f"lost {line.get('region')} division stores {child_count} != {count}")
        region_sum += money
        region_count += count
    store_sum = 0.0
    store_count = 0
    orphan = 0.0
    for record in records:
        if record.get("section") != "lost_revenue" or is_total_store(record.get("store") or ""):
            continue
        payload = record.get("payload") or {}
        amount = _number_or_zero(payload, "lost_revenue") - _number_or_zero(payload, "missed_sales")
        if not _region_of(record):
            orphan += amount
            continue
        store_sum += amount
        store_count += 1
    if abs(orphan) > 0.02:
        raise SystemExit(f"lost outside a region ${orphan:,.2f}")
    if not scoped and not store_count:
        return
    if not _close(region_sum, store_sum, 0.2):
        raise SystemExit(f"lost regions ${region_sum:,.2f} != stores ${store_sum:,.2f}")
    if region_count != store_count:
        raise SystemExit(f"lost region stores {region_count} != {store_count}")


def round_money_text(value):
    """$-prefixed pack strings print cents. Payload numbers stay as cooked."""
    if not isinstance(value, str):
        return value
    text = value.strip()
    if not text.startswith("$") and not text.startswith("-$"):
        return value
    cleaned = text.replace("$", "").replace(",", "").strip()
    try:
        number = float(cleaned)
    except ValueError:
        return value
    return _money_label(number)


def round_pack_currency(home: dict) -> None:
    tiles = home.get("companyTiles") or {}
    if isinstance(tiles, dict):
        for block in tiles.values():
            if not isinstance(block, dict) or not isinstance(block.get("values"), list):
                continue
            block["values"] = [round_money_text(item) for item in block["values"]]
    for line in home.get("regionLines") or []:
        if not isinstance(line, dict):
            continue
        line["value"] = round_money_text(line.get("value"))
        for child in line.get("children") or []:
            if isinstance(child, dict):
                child["value"] = round_money_text(child.get("value"))
    for row in home.get("regionTables") or []:
        if isinstance(row, dict):
            row["headline"] = round_money_text(row.get("headline"))


def apply_own_store_counts(summaries: list, latest: dict, shoppers: dict, picker_rollups: dict) -> None:
    """Each tile counts its own section. The shared chrome base lags stores 210 and 239."""
    counts: dict[str, int] = {}
    for section, _store in latest:
        counts[section] = counts.get(section, 0) + 1
    for item in summaries:
        section = item.get("section")
        if section in OWN_STORE_SECTIONS:
            item["storeCount"] = counts.get(section, 0)
            if section == "lost_revenue" and isinstance(item.get("secondary"), str):
                item["secondary"] = re.sub(
                    r"^[\d,]+ stores reported",
                    f"{item['storeCount']:,} stores reported",
                    item["secondary"],
                    count=1,
                )
    company = picker_rollups.get("company") if isinstance(picker_rollups, dict) else None
    if not isinstance(company, dict):
        return
    stores = {
        record.get("store")
        for record in shoppers.values()
        if record.get("section") == "picker_scorecard" and record.get("store")
    }
    company["stores"] = len(stores)


def cooked_at() -> str:
    """UTC time of this cook. HEARTBEAT_COOKED_AT overrides the clock in tests."""
    override = os.environ.get("HEARTBEAT_COOKED_AT", "").strip()
    if override:
        if len(override) < 20 or "/" in override or "\\" in override:
            raise SystemExit(f"pack metadata: cookedAt {override!r}")
        return override
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


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


def clear_invalid_schedule_under(schedule: dict) -> None:
    """Negative, zero, or missing efficiency is not a measured week. It is never 100% under."""
    for store in schedule.get("stores") or []:
        if not isinstance(store, dict):
            continue
        eff = store.get("eff")
        invalid = eff is None
        if not invalid:
            try:
                invalid = float(eff) <= 0
            except (TypeError, ValueError):
                invalid = True
        if invalid:
            store["under"] = None


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


def _schedule_region(division: str, region: str) -> str:
    """South 397 mapping: United and Southwest are South Region when the row is blank."""
    current = str(region or "").strip()
    if current:
        return current
    short = _DIVISION_REGION.get(canonical_division(division) or "")
    return f"{short} Region" if short else ""


def _fill_schedule_roster(schedule: dict, roster: dict) -> None:
    """Schedule identity takes the roster, then the South 210/239 map. A blank region follows the division."""
    for store in schedule.get("stores") or []:
        if not isinstance(store, dict):
            continue
        key = canonical_store(str(store.get("store") or ""))
        current = roster.get(key) or {}
        ident = SHEET_LOSS_IDENTITY.get(key) or {}
        if current.get("om"):
            store["om"] = current["om"]
        elif not store.get("om") and ident.get("om"):
            store["om"] = ident["om"]
        if not store.get("district"):
            store["district"] = current.get("district") or ident.get("district") or ""
        division = current.get("division") or store.get("division") or ident.get("division") or ""
        named = canonical_division(division) or division
        if named:
            store["division"] = named
        region = _schedule_region(store.get("division") or "", store.get("region") or "")
        if region:
            store["region"] = region


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


def _loss_header_key(header: str) -> str:
    text = " ".join(str(header or "").lower().split())
    if text in ("store", "store id", "store number", "store #"):
        return "store"
    if text in ("division", "first division"):
        return "division"
    if text in ("district",):
        return "district"
    return {
        "ecomm sales": "ecomm_sales",
        "total lost revenue (total opportunity)": "lost_revenue",
        "total lost revenue % (total opportunity)": "lost_revenue_pct",
        "total lost revenue (fy2026 goal)": "lost_revenue_goal",
        "total lost revenue (fy2026 goal) %": "lost_revenue_goal_pct",
        "post sub oos foregone revenue (total opportunity)": "post_sub_oos_foregone",
        "refund $ - fulfillment reasons (total opportunity)": "refund_lost",
        "capacity reduction (total opportunity)": "missed_sales",
        "total reduced capacity": "reduced_capacity",
        "cancelled orders (ldap driven) - lost sales (total opportunity)": "cancelled_lost",
        "kill switch lost sales (using $90) (total opportunity)": "kill_switch_lost",
    }.get(text, "")


def loss_sheet_division(store: str, sheet_division: str) -> str:
    """The Loss sheet writes Haggen on every row. That is not the store's division."""
    named = canonical_division(sheet_division)
    if named and named != "Haggen":
        return named
    return str((SHEET_LOSS_IDENTITY.get(store) or {}).get("division") or "")


def _read_loss_sheet(path: str) -> tuple[list[dict], float | None]:
    """Store rows on Daily Loss Revenue, plus the Total row's missed_sales dollars."""
    import openpyxl

    workbook = openpyxl.load_workbook(path, read_only=True, data_only=True)
    try:
        if "Loss Revenue" not in workbook.sheetnames:
            return [], None
        sheet = workbook["Loss Revenue"]
        rows = sheet.iter_rows(values_only=True)
        header = next(rows, None)
        if not header:
            return [], None
        keys = [_loss_header_key("" if value is None else str(value)) for value in header]
        if "store" not in keys or "lost_revenue" not in keys:
            return [], None
        out = []
        company_missed = None
        for line in rows:
            cells = list(line)
            store_raw = ""
            division = ""
            district = ""
            payload: dict[str, float] = {}
            for index, key in enumerate(keys):
                if not key or index >= len(cells):
                    continue
                value = cells[index]
                if key == "store":
                    store_raw = "" if value is None else str(value).strip()
                    continue
                if key == "division":
                    division = "" if value is None else str(value).strip()
                    continue
                if key == "district":
                    district = "" if value is None else str(value).strip()
                    continue
                if value is None or value == "":
                    continue
                try:
                    number = float(value)
                except (TypeError, ValueError):
                    continue
                if number != number or number in (float("inf"), float("-inf")):
                    continue
                if key not in payload:
                    payload[key] = number
            if not store_raw or "applied filter" in store_raw.lower():
                continue
            if is_total_store(store_raw):
                if "missed_sales" in payload:
                    company_missed = payload["missed_sales"]
                continue
            store = canonical_store(store_raw)
            if not store or is_total_store(store):
                continue
            out.append(
                {
                    "store": store,
                    "division": division,
                    "district": district,
                    "payload": payload,
                }
            )
        return out, company_missed
    finally:
        workbook.close()


def read_loss_sheet(path: str) -> list[dict]:
    """Store rows on Daily Loss Revenue. Blank cells stay absent, including a blank Goal %."""
    rows, _company_missed = _read_loss_sheet(path)
    return rows


def merge_off_roster_loss(latest: dict, roster: dict, path: str) -> tuple[int, float | None]:
    """Keep every Loss Revenue store row and stamp missed_sales onto rows the sqlite cook already has.

    Blank Capacity Reduction cells stay absent. Other payload keys, including a blank Goal %, are left alone.
    """
    added = 0
    rows, company_missed = _read_loss_sheet(path)
    for row in rows:
        store = row["store"]
        missed = (row.get("payload") or {}).get("missed_sales")
        existing = latest.get(("lost_revenue", store))
        if existing:
            if missed is not None:
                payload = existing.get("payload")
                if not isinstance(payload, dict):
                    payload = {}
                    existing["payload"] = payload
                payload["missed_sales"] = missed
            continue
        ident = SHEET_LOSS_IDENTITY.get(store) or {}
        division = loss_sheet_division(store, row.get("division") or "")
        record = {
            "store": store,
            "name": "",
            "division": division,
            "district": ident.get("district") or row.get("district") or "",
            "om": ident.get("om") or "",
            "recorded": "",
            "payload": row["payload"],
            "section": "lost_revenue",
        }
        latest[("lost_revenue", store)] = record
        seeded = dict(record)
        seeded["division"] = division
        _merge_roster(roster, seeded, prefer_roster=False)
        added += 1
    return added, company_missed


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
            if om_raw and om_raw.lower() != "total" and is_person_om(om_raw):
                om = om_raw
            elif om_raw:
                om = ""
            if not store_raw or store_raw.lower() == "total":
                continue
            store = canonical_store(store_raw)
            if not store or is_total_store(store):
                continue
            # A blank OM_ID on this store does not inherit the previous person.
            people[store] = {
                "division": division,
                "district": district,
                "om": om if (om_raw and is_person_om(om_raw)) else "",
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
            if person:
                current["om"] = person
    for record in records:
        ident = people.get(record["store"])
        if not ident:
            continue
        if ident.get("division"):
            record["division"] = ident["division"]
        if ident.get("district"):
            record["district"] = ident["district"]
        if ident.get("om"):
            record["om"] = ident["om"]
    return {"stores": len(people), "named": named}


def prefer_pph_identity(roster: dict, records: list) -> None:
    """PPH names the store when the Daily Roster sheet has no row for it."""
    for record in records:
        if record.get("section") != "pph":
            continue
        current = roster.get(record.get("store") or "")
        if not current:
            continue
        if record.get("division"):
            current["division"] = canonical_division(record["division"])
        if record.get("district"):
            current["district"] = record["district"]
        if is_person_om(record.get("om") or ""):
            current["om"] = record["om"]


def apply_pph_summary(summaries: list, records: list) -> None:
    """80 and above is the goal. 74 up to 80 is the gap. Below 74 is the risk count."""
    values = []
    for record in records:
        if record.get("section") != "pph":
            continue
        raw = (record.get("payload") or {}).get("pph")
        if raw is None:
            continue
        try:
            values.append(float(raw))
        except (TypeError, ValueError):
            continue
    if not values:
        return
    at_goal = sum(value >= 80 for value in values)
    between = sum(74 <= value < 80 for value in values)
    below = sum(value < 74 for value in values)
    average = sum(values) / len(values)
    if average >= 80:
        health = "good"
    elif average >= 74:
        health = "watch"
    else:
        health = "risk"
    secondary = f"{at_goal} of {len(values)} at 80 · {between} between 74 and 80 · {below} below 74"
    for item in summaries:
        if item.get("section") == "pph":
            item["secondary"] = secondary
            item["health"] = health


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
            if section == "labor":
                raw_payload = loads(fact["payload_json"], {})
                if not isinstance(raw_payload, dict):
                    raw_payload = {}
                hours = labor_act_hours(raw_payload)
                if hours is not None:
                    record["payload"]["weight"] = hours
                apply_labor_blanks(record["payload"], raw_payload)
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
    company_missed = None
    if roster_xlsx:
        _added, company_missed = merge_off_roster_loss(latest, roster, roster_xlsx)
    records = list(latest.values()) + list(shoppers.values())
    prefer_pph_identity(roster, records)
    people = read_roster_people(roster_xlsx) if roster_xlsx else {}
    if people:
        stats = apply_roster_people(roster, records, people)
        print(
            f"roster people: {stats['named']} named of {stats['stores']} stores"
            f" ({len({item['om'] for item in people.values() if item.get('om')})} names)"
        )
    for item in roster.values():
        item["division"] = canonical_division(item.get("division") or "")
    # Division belongs to the store. Missing Items and Schedule Quality sheets
    # say DENVER, INTERMOUNTAIN, and JEWEL. The roster display name wins, and
    # a sheet token that is not on the roster still goes through the same map.
    for record in records:
        record["division"] = roster_division(record, roster)
        current = roster.get(record["store"])
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
    apply_pph_summary(summaries, records)
    company_tiles = json.loads(json.dumps(chrome.get("companyTiles") or {}))
    lost_market = lost_market_payload(db)
    if company_missed is not None:
        lost_market = dict(lost_market)
        lost_market["missed_sales"] = company_missed
    apply_lost_tile_scale(company_tiles, lost_market)
    labor_market = labor_market_payload(db)
    apply_labor_aiv_tile(company_tiles, labor_market)
    workbook_total = None
    if roster_xlsx:
        from workbook_totals import read_workbook_totals

        workbook_total = read_workbook_totals(roster_xlsx)
    apply_workbook_missed(company_tiles, workbook_total)
    if not published or len(str(published)) < 20:
        raise SystemExit(f"refusing pack write: publishedAt {published!r}")
    schema = schema_version()
    sha = cook_sha()
    cooked = cooked_at()
    picker_rollups = build_picker_rollups(records)
    apply_own_store_counts(summaries, latest, shoppers, picker_rollups)
    region_line_rows, table_rows = build_region_views(records)
    assert_additive_region_sums(region_line_rows, records, workbook_total)

    def stamped(payload: dict) -> dict:
        payload["publishedAt"] = published
        payload["schemaVersion"] = schema
        payload["cookSha"] = sha
        payload["cookedAt"] = cooked
        metadata = payload.get("metadata")
        if isinstance(metadata, dict):
            metadata["cookedAt"] = cooked
        return payload

    home = stamped({
        "metadata": {
            "schemaVersion": schema,
            "cookSha": sha,
        },
        "summaries": summaries,
        "companyTiles": company_tiles,
        "laborMarket": labor_bridge(labor_market),
        "pickerRollups": picker_rollups,
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
        "regionLines": region_line_rows,
        "regionTables": table_rows,
    })
    if workbook_total is not None:
        home["workbookTotal"] = workbook_total
    round_pack_currency(home)
    _write(out / "home.json", home)
    schedule = read_schedule(db) or read_schedule_file(source.parent / "schedule-check.json")
    schedule_path = out / "schedule.json"
    if schedule:
        _fill_schedule_roster(schedule, roster)
        clear_blank_schedule(schedule)
        clear_invalid_schedule_under(schedule)
        schedule["summaryTitle"] = schedule_summary_title(schedule.get("summaryTitle") or "", schedule.get("week") or 0)
        _write(schedule_path, stamped(schedule))
    else:
        # Keep the URL as JSON. An older file must not keep stores this pack lacks.
        _write(schedule_path, stamped(empty_schedule()))
    grouped: dict[str, list] = {section: [] for section in SECTIONS}
    for record in latest.values():
        row = {
            "store": record["store"],
            "name": record["name"],
            "division": record["division"],
            "district": record["district"],
            "om": record["om"],
            "payload": record["payload"],
        }
        if record["section"] == "labor" and labor_source_issue(record["payload"]):
            row["sourceIssue"] = "source data issue"
        grouped[record["section"]].append(row)
    for section, rows in grouped.items():
        rows.sort(key=lambda item: (len(item["store"]), item["store"]))
        _write(section_dir / f"{section}.json", stamped({"section": section, "rows": rows}))
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
        _write(section_dir / f"{section}.json", stamped({"section": section, "rows": rows}))
    _write(out / "presub.json", stamped({"scopes": presub}))
    db.close()
    check_pack(out)


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


def schema_version() -> int:
    text = (Path(__file__).resolve().parents[1] / "public" / "schema.js").read_text(encoding="utf-8")
    match = re.search(r"export const SCHEMA_VERSION = (\d+)", text)
    if not match:
        raise SystemExit("pack metadata: schema.js has no SCHEMA_VERSION")
    return int(match.group(1))


def cook_sha() -> str:
    """Git SHA of the cook that wrote this pack. HEARTBEAT_COOK_SHA overrides git."""
    override = os.environ.get("HEARTBEAT_COOK_SHA", "").strip()
    if override:
        return override
    root = Path(__file__).resolve().parents[2]
    try:
        sha = subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        sha = ""
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise SystemExit("pack metadata: cook git SHA is missing")
    return sha


def check_pack(out: Path) -> None:
    """Refuse a pack that is missing the keys a later cook already depends on.

    The committed checker is `node web/check_pack.mjs <dir>`. Extract runs it
    so a bad pack is not written for upload. HEARTBEAT_SKIP_PACK_CHECK is only
    for the synthetic extract fixture.
    """
    if os.environ.get("HEARTBEAT_SKIP_PACK_CHECK"):
        return
    script = Path(__file__).resolve().parents[1] / "check_pack.mjs"
    completed = subprocess.run(["node", str(script), str(out)], check=False)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode or 1)


def main() -> None:
    if len(sys.argv) not in (3, 4):
        raise SystemExit("usage: extract_web_pack.py <company-seat.sqlite> <out-dir> [daily-roster.xlsx]")
    extract(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) == 4 else None)


if __name__ == "__main__":
    main()
