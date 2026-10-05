#!/usr/bin/env python3
"""Cook Schedule Review Week *.xlsx into current.sqlite schedule rows.

The workbook is formula-driven. This reads the raw tabs and re-implements the
Store Detail rules. ACTION NEEDED helper rows are not the source. Excel's
cached values are only a cross-check.

Percents in the pack are 0–100. The shipped pack is the schedule_pack,
schedule_market, and schedule_store tables inside current.sqlite. A json path
is still accepted so the Mac cook can write a local file. That file is not
the Heartbeat pack.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import sys
from datetime import datetime, timezone

SALES_GATE = 30_000.0
UNDER_GATE = 10.0  # percent
FOUR_UNDER_GATE = 9.0  # strictly greater than 9%
OVER_GATE = 15.0

OFFICIAL_DIVISIONS = [
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
]

DIVISION_ALIASES = {
    "SHAWS": "Shaws",
    "MID ATLANTIC": "Mid-Atlantic",
    "JEWEL": "Jewel Osco",
    "JEWEL OSCO": "Jewel Osco",
    "SOUTHERN": "Southern",
    "UNITED": "United",
    "SOUTHWEST": "Southwest",
    "NOR CALIFORNIA": "NorCal",
    "NORTHERN CALIFORNIA": "NorCal",
    "NORCAL": "NorCal",
    "SO CALIFORNIA": "SoCal",
    "SOUTHERN CALIFORNIA": "SoCal",
    "SOCAL": "SoCal",
    "MOUNTAINWEST": "Mountain West",
    "MOUNTAIN WEST": "Mountain West",
    "DENVER": "Mountain West",
    "INTERMOUNTAIN": "Mountain West",
    "SEATTLE": "Seattle",
    "HAGGEN": "Haggen",
    "PORTLAND": "Portland",
}

REGIONS = {
    "Shaws": "East Region",
    "Mid-Atlantic": "East Region",
    "Jewel Osco": "East Region",
    "Southern": "South Region",
    "United": "South Region",
    "Southwest": "South Region",
    "NorCal": "California Region",
    "SoCal": "California Region",
    "Haggen": "West Region",
    "Seattle": "West Region",
    "Portland": "West Region",
    "Mountain West": "West Region",
}

DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]


def compact_key(value) -> str:
    text = "" if value is None else str(value)
    return " ".join(text.upper().replace(".", " ").replace("-", " ").split())


def canonical_division(value) -> str:
    if value is None:
        return ""
    text = str(value).strip()
    if not text or text.lower() == "total":
        return ""
    alias = DIVISION_ALIASES.get(compact_key(text))
    if alias:
        return alias
    for name in OFFICIAL_DIVISIONS:
        if name.lower() == text.lower():
            return name
    return text


def region_for(division: str) -> str:
    return REGIONS.get(division, "")


def store_key(value):
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, float) and value == int(value):
        value = int(value)
    text = str(value).strip()
    if not text or text.lower() in {"store", "total"}:
        return None
    try:
        number = int(float(text))
    except ValueError:
        return None
    if number <= 0:
        return None
    return str(number)


def is_total(value) -> bool:
    return value is not None and str(value).strip().lower() == "total"


def percent(value):
    if value is None or value == "":
        return None
    if isinstance(value, str):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return round(number * 100.0, 6)


def number(value):
    if value is None or value == "":
        return None
    if isinstance(value, str):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def qualifies(sales, under, four_under, over) -> bool:
    """Average sales >= $30,000 and (under >= 10% or 4-wk under > 9% or over >= 15%)."""
    if sales is None or sales < SALES_GATE:
        return False
    if under is not None and under >= UNDER_GATE:
        return True
    if four_under is not None and four_under - FOUR_UNDER_GATE > 1e-6:
        return True
    if over is not None and over >= OVER_GATE:
        return True
    return False


def average(values):
    nums = [v for v in values if v is not None]
    if not nums:
        return None
    return sum(nums) / len(nums)


def round2(value):
    if value is None:
        return None
    return round(value + 1e-12, 2)


def rows_of(workbook, name):
    sheet = workbook[name]
    return [tuple(row) for row in sheet.iter_rows(values_only=True)]


def find_week(sheet_names):
    import re

    found = []
    for name in sheet_names:
        match = re.search(r"(?:Store|Market) Look WK(\d+)", name, re.IGNORECASE)
        if match:
            found.append(int(match.group(1)))
    if not found:
        raise SystemExit("No Store Look WK## / Market Look WK## tab. Week number is unknown.")
    week = found[0]
    if any(item != week for item in found):
        raise SystemExit(f"Week tabs disagree: {found}")
    return week


def index_by_store(table, store_column, skip_rows=1):
    indexed = {}
    for row in table[skip_rows:]:
        if store_column >= len(row):
            continue
        key = store_key(row[store_column])
        if key:
            indexed[key] = row
    return indexed


def load_sales(table):
    """Column Z (index 25) is Sales Total $. Average Sales Volume = that / 4."""
    sales = {}
    for row in table[2:]:
        key = store_key(row[0] if row else None)
        if not key or len(row) <= 25:
            continue
        total = number(row[25])
        if total is None:
            continue
        sales[key] = round(total / 4.0, 4)
    return sales


def load_quality(table):
    """Match TEXT(store, \"0000\"). 4-wk under is col E, 4-wk over col F, Pch vs Sch is col J."""
    quality = {}
    for row in table[1:]:
        if len(row) < 10:
            continue
        key = store_key(row[2])
        if not key:
            continue
        quality[key] = {
            "fourUnder": percent(row[4]),
            "fourOver": percent(row[5]),
            "pch": percent(row[9]),
        }
    return quality


def load_days(workbook):
    under = {}
    over = {}
    for name in DAYS:
        table = rows_of(workbook, name)
        for row in table[1:]:
            if len(row) < 5:
                continue
            key = store_key(row[2])
            if not key:
                continue
            over.setdefault(key, [None] * 7)
            under.setdefault(key, [None] * 7)
            index = DAYS.index(name)
            over[key][index] = percent(row[3])
            under[key][index] = percent(row[4])
    return under, over


def load_stars(table):
    stars = {}
    for row in table[2:]:
        if len(row) < 10:
            continue
        key = store_key(row[3])
        if not key:
            continue
        stars[key] = number(row[9])
    return stars


def load_roster(table):
    division = ""
    district = ""
    om = ""
    roster = {}
    for row in table[2:]:
        raw_div = row[0] if len(row) > 0 else None
        raw_dist = row[1] if len(row) > 1 else None
        raw_om = row[3] if len(row) > 3 else None
        raw_store = row[4] if len(row) > 4 else None
        if raw_div is not None and str(raw_div).strip():
            if not is_total(raw_div):
                division = canonical_division(raw_div)
                district = ""
                om = ""
        if raw_dist is not None and str(raw_dist).strip() and not is_total(raw_dist):
            district = str(raw_dist).strip()
        if raw_om is not None and str(raw_om).strip() and not is_total(raw_om):
            om = str(raw_om).strip()
        key = store_key(raw_store)
        if not key:
            continue
        roster[key] = {
            "division": division,
            "district": district,
            "om": om,
        }
    return roster


def load_markets(table):
    markets = []
    for row in table[1:]:
        if not row or row[0] is None:
            continue
        label = str(row[0]).strip()
        if not label or label.lower().startswith("applied filters"):
            continue
        if label.lower() == "total":
            name = "Total"
        else:
            name = canonical_division(label) or label
        markets.append(
            {
                "label": name,
                "under": percent(row[1] if len(row) > 1 else None),
                "over": percent(row[2] if len(row) > 2 else None),
                "eff": percent(row[3] if len(row) > 3 else None),
            }
        )
    return markets


def banner_count(table):
    import re

    for row in table[:6]:
        for cell in row[:3]:
            if not isinstance(cell, str):
                continue
            match = re.search(r"snapshot qualify now:\s*(\d+)", cell)
            if match:
                return int(match.group(1))
    return None


def summary_title(table):
    for row in table[:3]:
        for cell in row[:6]:
            if isinstance(cell, str) and "Schedule Review Summary" in cell:
                return cell.strip()
    return ""


def load_store_detail(table):
    """Store Detail has the under/over cells Stores Current Week leaves blank."""
    detail = {}
    for row in table[1:]:
        if len(row) < 7:
            continue
        key = store_key(row[3] if len(row) > 3 else None)
        if not key:
            continue
        detail[key] = {
            "under": percent(row[5]) if len(row) > 5 else None,
            "over": percent(row[6]) if len(row) > 6 else None,
        }
    return detail


def fill_metric(current, fallback):
    if current is not None:
        return current
    return fallback


def cook_workbook(path: str) -> dict:
    import openpyxl

    workbook = openpyxl.load_workbook(path, read_only=True, data_only=True)
    try:
        week = find_week(workbook.sheetnames)
        current = rows_of(workbook, "Stores Current Week")
        quality = load_quality(rows_of(workbook, "Last 4 Week Quality"))
        sales = load_sales(rows_of(workbook, "Sales AVG Last 4 Wks"))
        day_under, day_over = load_days(workbook)
        stars = load_stars(rows_of(workbook, "5 Star Last 5 Weeks"))
        roster = load_roster(rows_of(workbook, "Roster"))
        detail = load_store_detail(rows_of(workbook, "Store Detail")) if "Store Detail" in workbook.sheetnames else {}
        markets = load_markets(rows_of(workbook, f"Market Look WK{week}"))
        banner = banner_count(rows_of(workbook, "ACTION NEEDED"))
        title = summary_title(rows_of(workbook, "Summary"))
    finally:
        workbook.close()

    stores = []
    for row in current[1:]:
        if len(row) < 6:
            continue
        key = store_key(row[2])
        if not key:
            continue
        identity = roster.get(key, {})
        division = identity.get("division") or canonical_division(row[0])
        district = identity.get("district") or ("" if row[1] is None else str(row[1]).strip())
        if district.lower() == "total":
            district = ""
        om = identity.get("om") or ""
        quality_row = quality.get(key, {})
        detail_row = detail.get(key, {})
        stores.append(
            {
                "store": key,
                "region": region_for(division),
                "division": division,
                "district": district,
                "om": om,
                "sales": sales.get(key),
                "under": fill_metric(percent(row[4]), detail_row.get("under")),
                "over": fill_metric(percent(row[3]), detail_row.get("over")),
                "eff": percent(row[5]),
                "pch": quality_row.get("pch"),
                "fourUnder": quality_row.get("fourUnder"),
                "fourOver": quality_row.get("fourOver"),
                "star": stars.get(key),
                "dayUnder": day_under.get(key, [None] * 7),
                "dayOver": day_over.get(key, [None] * 7),
            }
        )
    stores.sort(key=lambda item: int(item["store"]))
    mtime = os.path.getmtime(path)
    published = datetime.fromtimestamp(mtime, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    pack = {
        "publishedAt": published,
        "week": week,
        "filename": os.path.basename(path),
        "summaryTitle": title,
        "workbookActionBanner": banner,
        "markets": markets,
        "stores": stores,
    }
    pack["crossCheck"] = cross_check(pack)
    return pack


def market_labeled(pack, label):
    for market in pack["markets"]:
        if market["label"].lower() == label.lower():
            return market
    return None


def cross_check(pack) -> dict:
    stores = pack["stores"]
    action = [
        store
        for store in stores
        if qualifies(store.get("sales"), store.get("under"), store.get("fourUnder"), store.get("over"))
    ]
    not_scheduled = [
        store
        for store in stores
        if store.get("under") is not None
        and store.get("eff") is not None
        and store["under"] >= 99.5
        and abs(store["eff"]) < 0.05
    ]
    market = market_labeled(pack, "Total") or {}
    store_under = average([store.get("under") for store in stores])
    store_over = average([store.get("over") for store in stores])
    eff = average([store.get("eff") for store in stores])
    pch = average([store.get("pch") for store in stores])
    under_count = sum(1 for store in stores if store.get("under") is not None and store["under"] > 0)
    over_count = sum(1 for store in stores if store.get("over") is not None and store["over"] > 0)
    regions = {}
    for store in stores:
        regions.setdefault(store.get("region") or "(none)", []).append(store)
    return {
        "scope": len(stores),
        "underCount": under_count,
        "overCount": over_count,
        "eff": eff,
        "pch": pch,
        "marketUnder": market.get("under"),
        "marketOver": market.get("over"),
        "storeUnder": store_under,
        "storeOver": store_over,
        "actionCount": len(action),
        "bannerCount": pack.get("workbookActionBanner"),
        "notScheduled": len(not_scheduled),
        "regions": {name: len(rows) for name, rows in regions.items()},
        "summaryTitle": pack.get("summaryTitle") or "",
        "week": pack.get("week"),
    }


def company_numbers_ok(report: dict) -> bool:
    """The seven company figures. A miss here is a real cook failure."""
    return (
        report["scope"] == 2163
        and report["underCount"] == 2008
        and report["overCount"] == 1566
        and round2(report["eff"]) == 64.97
        and round2(report["pch"]) == 70.28
        and round2(report["marketUnder"]) == 41.07
        and round2(report["marketOver"]) == 4.03
    )


def print_cross_check(report: dict) -> bool:
    """Print the cross-check. True when the seven company numbers match.

    Store-average, the 472-vs-468 banner, and the Summary title week are notes.
    They do not block the json write and they do not change the exit code.
    """
    def line(label, actual, expected, digits=2):
        shown = round2(actual) if isinstance(actual, float) else actual
        status = "OK" if shown == expected else "MISMATCH"
        print(f"  {label}: {shown} expected {expected} {status}")

    print("Schedule check cross-check")
    line("scope", report["scope"], 2163, 0)
    line("# under", report["underCount"], 2008, 0)
    line("# over", report["overCount"], 1566, 0)
    line("Sch Eff", report["eff"], 64.97)
    line("Pch vs Sch", report["pch"], 70.28)
    line("Market Look under", report["marketUnder"], 41.07)
    line("Market Look over", report["marketOver"], 4.03)
    ok = company_numbers_ok(report)
    print(
        f"  Stores Current Week average under/over: {round2(report['storeUnder'])}% / {round2(report['storeOver'])}%"
        "  informational (company card uses Market Look, not this average)"
    )
    banner_note = report["actionCount"] != report["bannerCount"]
    print(
        f"  ACTION NEEDED live formula: {report['actionCount']}"
        f"  workbook banner: {report['bannerCount']}"
        f"  {'note' if banner_note else 'OK'}"
    )
    if banner_note:
        print(
            f"  informational: the app page shows {report['actionCount']} action stores."
            f" The workbook banner said {report['bannerCount']}."
        )
    print(f"  Not scheduled yet (under 100 / eff 0): {report['notScheduled']}")
    print(f"  Week from tabs: {report['week']}  Summary title: {report['summaryTitle']}")
    title = report["summaryTitle"] or ""
    if title and f"Week {report['week']}" not in title:
        print(
            f"  informational: Summary title week does not match the WK tabs."
            f" The app uses week {report['week']} from the tabs."
        )
    print(f"  Region scopes: {report['regions']}")
    if not ok:
        print("  Company numbers MISMATCH. This blocks a clean cook.")
    return ok


def is_schedule_workbook(name: str) -> bool:
    """Daily iCloud saves use spaces. Downloads sometimes use underscores."""
    if not name or name.startswith("~$") or name.startswith("."):
        return False
    folded = name.replace("_", " ").lower()
    if not folded.endswith(".xlsx"):
        return False
    if "schedule review" not in folded:
        return False
    return "summary" in folded or folded.startswith("schedule review week ")


def newest_schedule_workbook(folder: str):
    if not folder or not os.path.isdir(folder):
        return None
    found = []
    for name in os.listdir(folder):
        if not is_schedule_workbook(name):
            continue
        path = os.path.join(folder, name)
        if os.path.isfile(path):
            found.append(path)
    if not found:
        return None
    found.sort(key=lambda path: os.path.getmtime(path), reverse=True)
    return found[0]


def sheet_publishable(pack: dict) -> bool:
    """A schedule pack can ship when the workbook itself has a week and stores."""
    try:
        week = int(pack.get("week") or 0)
    except (TypeError, ValueError):
        return False
    stores = pack.get("stores") or []
    return week > 0 and len(stores) > 0


def write_pack(pack: dict, dest: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
    payload = {key: value for key, value in pack.items() if key != "crossCheck"}
    with open(dest, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, separators=(",", ":"))
        handle.write("\n")


SCHEDULE_DDL = """
CREATE TABLE IF NOT EXISTS schedule_pack (
    id INTEGER PRIMARY KEY,
    published_at TEXT NOT NULL,
    week INTEGER NOT NULL,
    filename TEXT NOT NULL,
    summary_title TEXT NOT NULL,
    workbook_action_banner INTEGER
);
CREATE TABLE IF NOT EXISTS schedule_market (
    label TEXT PRIMARY KEY,
    under REAL,
    over REAL,
    eff REAL
);
CREATE TABLE IF NOT EXISTS schedule_store (
    store TEXT PRIMARY KEY,
    region TEXT NOT NULL,
    division TEXT NOT NULL,
    district TEXT NOT NULL,
    om TEXT NOT NULL,
    sales REAL,
    under REAL,
    over REAL,
    eff REAL,
    pch REAL,
    four_under REAL,
    four_over REAL,
    star REAL,
    day_under_json TEXT NOT NULL,
    day_over_json TEXT NOT NULL
);
"""


def write_sqlite(pack: dict, dest: str) -> None:
    """Replace schedule rows inside an existing current.sqlite. Fact rows stay put."""
    import sqlite3

    if not os.path.isfile(dest):
        raise SystemExit(f"Refusing to create {dest}. Schedule rows belong inside an existing current.sqlite.")
    payload = {key: value for key, value in pack.items() if key != "crossCheck"}
    connection = sqlite3.connect(dest)
    try:
        connection.executescript(SCHEDULE_DDL)
        connection.execute("DELETE FROM schedule_store")
        connection.execute("DELETE FROM schedule_market")
        connection.execute("DELETE FROM schedule_pack")
        connection.execute(
            """
            INSERT INTO schedule_pack(
                id, published_at, week, filename, summary_title, workbook_action_banner
            ) VALUES (1, ?, ?, ?, ?, ?)
            """,
            (
                payload.get("publishedAt") or "",
                int(payload.get("week") or 0),
                payload.get("filename") or "",
                payload.get("summaryTitle") or "",
                payload.get("workbookActionBanner"),
            ),
        )
        for market in payload.get("markets") or []:
            connection.execute(
                "INSERT INTO schedule_market(label, under, over, eff) VALUES (?, ?, ?, ?)",
                (market.get("label") or "", market.get("under"), market.get("over"), market.get("eff")),
            )
        for store in payload.get("stores") or []:
            connection.execute(
                """
                INSERT INTO schedule_store(
                    store, region, division, district, om, sales, under, over, eff, pch,
                    four_under, four_over, star, day_under_json, day_over_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    store.get("store") or "",
                    store.get("region") or "",
                    store.get("division") or "",
                    store.get("district") or "",
                    store.get("om") or "",
                    store.get("sales"),
                    store.get("under"),
                    store.get("over"),
                    store.get("eff"),
                    store.get("pch"),
                    store.get("fourUnder"),
                    store.get("fourOver"),
                    store.get("star"),
                    json.dumps(store.get("dayUnder") or [None] * 7, separators=(",", ":")),
                    json.dumps(store.get("dayOver") or [None] * 7, separators=(",", ":")),
                ),
            )
        connection.commit()
    finally:
        connection.close()


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Cook a Schedule Review workbook into current.sqlite")
    parser.add_argument("workbook", nargs="?", help="xlsx path. Omit with --find.")
    parser.add_argument("output", nargs="?", help="Optional local json path. Not the shipped pack.")
    parser.add_argument("--find", help="Folder of Schedule Review Week *.xlsx. Newest mtime wins. ~$ ignored.")
    parser.add_argument("--sqlite", help="current.sqlite path. Schedule rows are replaced inside this pack.")
    parser.add_argument("--check", action="store_true", help="Print the cross-check and exit 1 on a company-number miss.")
    parser.add_argument(
        "--publish-sheet",
        action="store_true",
        help=(
            "Write this workbook's own rows even when they miss the historical company lock. "
            "Still refuses an empty week or an empty store list. Does not substitute lock numbers."
        ),
    )
    args = parser.parse_args(argv)
    # `--find FOLDER schedule-check.json` used to bind the json path to workbook,
    # then --find replaced the workbook, so output stayed empty and the process
    # exited 0 without writing. That positional is the output path.
    if args.find and args.workbook and not args.output:
        args.output = args.workbook
        args.workbook = None
    return args


def main(argv=None) -> int:
    args = parse_args(argv)
    path = args.workbook
    if args.find:
        path = newest_schedule_workbook(args.find)
        if not path:
            print(f"No Schedule Review Week *.xlsx in {args.find}")
            return 1
    if not path:
        print("workbook path or --find is required", file=sys.stderr)
        return 2
    pack = cook_workbook(path)
    report = pack["crossCheck"]
    ok = print_cross_check(report)
    if args.check and not ok:
        return 1
    if (args.sqlite or args.publish_sheet) and not sheet_publishable(pack):
        print("Schedule cook refused: week or store rows are missing. Nothing written.")
        return 1
    if not ok and not args.publish_sheet:
        print("Company-number MISMATCH. Schedule rows were not written into current.sqlite.")
        return 1
    if not ok:
        print(
            "Historical company lock missed. Publishing this workbook's own rows. "
            "Lock numbers were not substituted."
        )
    if args.output:
        write_pack(pack, args.output)
        print(f"Wrote {args.output} ({os.path.getsize(args.output)} bytes, {report['scope']} stores)")
    if args.sqlite:
        write_sqlite(pack, args.sqlite)
        print(f"Cooked schedule rows into {args.sqlite} ({report['scope']} stores)")
    elif not args.output:
        print("No output path. Nothing written.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
