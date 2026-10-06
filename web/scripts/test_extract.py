#!/usr/bin/env python3
"""Synthetic company seat. Confirms the web pack drops shopper rows and sqlite."""

import json
import os
import sqlite3
import tempfile
from pathlib import Path

os.environ["HEARTBEAT_SKIP_PACK_CHECK"] = "1"

import importlib.util

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("extract_web_pack", ROOT / "extract_web_pack.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        db_path = Path(tmp) / "current.sqlite"
        out = Path(tmp) / "out"
        db = sqlite3.connect(db_path)
        db.executescript(
            """
            CREATE TABLE pack_meta (id INTEGER PRIMARY KEY, written_at TEXT);
            CREATE TABLE dash_chrome (id INTEGER PRIMARY KEY, json TEXT NOT NULL);
            CREATE TABLE facts (
              section TEXT, store_number TEXT, division TEXT, operations_om TEXT,
              store_name TEXT, recorded_on TEXT, payload_json TEXT, text_json TEXT
            );
            CREATE TABLE presub_top (scope TEXT PRIMARY KEY, json TEXT NOT NULL);
            CREATE TABLE schedule_pack (
              id INTEGER PRIMARY KEY, published_at TEXT, week INTEGER, filename TEXT,
              summary_title TEXT, workbook_action_banner INTEGER
            );
            CREATE TABLE schedule_market (label TEXT, under REAL, over REAL, eff REAL);
            CREATE TABLE schedule_store (
              store TEXT, region TEXT, division TEXT, district TEXT, om TEXT,
              sales REAL, under REAL, over REAL, eff REAL, pch REAL,
              four_under REAL, four_over REAL, star REAL,
              day_under_json TEXT, day_over_json TEXT
            );
            """
        )
        chrome = {
            "publishedAt": "2026-09-28T19:10:00Z",
            "summaries": [
                {
                    "section": "prep_not_ready",
                    "storeCount": 36,
                    "headline": None,
                    "headlineLabel": "PNR %",
                    "secondary": "Only 36 of 1,297 stores reported Prep Not Ready this upload.",
                    "health": "none",
                    "watchCount": 0,
                    "riskCount": 0,
                },
                {
                    "section": "lost_revenue",
                    "storeCount": 610,
                    "headline": 869751.99,
                    "headlineLabel": "Total lost revenue",
                    "secondary": "Total Lost Revenue % (Total Opportunity)",
                    "health": "risk",
                    "watchCount": 0,
                    "riskCount": 1,
                },
                {
                    "section": "five_star",
                    "storeCount": 611,
                    "headline": 2.6,
                    "headlineLabel": "Avg star rating",
                    "secondary": "331 of 2161 at 5.00",
                    "health": "risk",
                    "watchCount": 0,
                    "riskCount": 1,
                },
            ],
            "companyTiles": {
                "prep_not_ready": {
                    "labels": ["Stores", "PNR %", "Goal", "Watch"],
                    "values": ["36 of 1,297", "—", "—", "—"],
                }
            },
            "pickerRollups": {
                "company": {"shoppers": 4, "stores": 1, "healthy": 3, "watch": 1, "risk": 0}
            },
            "preSubItemTabPresent": False,
            "packs": {
                "huge": [{"line": {"label": "do-not-copy", "value": "9", "count": 1}}],
                "lost_revenue": [
                    {
                        "line": {"label": "East Region", "value": "$393,334.12", "count": 610, "health": "risk"},
                        "children": [{"label": "Shaws", "value": "$1.00", "count": 13, "health": "risk"}],
                        "flags": [],
                    },
                    {
                        "line": {"label": "South Region", "value": "$136,425", "count": 395, "health": "risk"},
                        "children": [],
                        "flags": [],
                    },
                ],
                "five_star": [],
            },
            "tables": {"sales": [{"label": "do-not-copy"}]},
        }
        db.execute("INSERT INTO pack_meta VALUES (1, '2026-09-28T19:00:00Z')")
        db.execute("INSERT INTO dash_chrome VALUES (1, ?)", (json.dumps(chrome),))
        db.execute(
            "INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "sales",
                "0117",
                "SHAWS",
                "Ada",
                "Harbor",
                "2026-09-28",
                json.dumps({"sales_dollars": 1200, "secret_blob": 1}),
                json.dumps({"district": "03"}),
            ),
        )
        db.execute(
            "INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "labor",
                "TOTAL",
                "",
                "",
                "",
                "2026-09-28",
                json.dumps({"charged_hrs": 999999}),
                "{}",
            ),
        )
        db.execute(
            "INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "labor",
                "1",
                "SoCal",
                "Ada",
                "Store 1",
                "2026-09-28",
                json.dumps({"act_hrs": 383, "aiv_impact_pct": -0.38645958215580284, "cost_trgt_pct": 11.4}),
                json.dumps({"labor_grain": "store", "district": "01"}),
            ),
        )
        db.execute(
            "INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "picker_scorecard",
                "117",
                "Shaws",
                "Ada",
                "Harbor",
                "2026-09-28",
                "{}",
                json.dumps({"shopper_name": "Secret Shopper"}),
            ),
        )
        db.execute(
            "INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "store_roster",
                "3436",
                "Haggen",
                "Haggen 1",
                "",
                "2026-09-28",
                "{}",
                json.dumps({"district": "39", "om_area": "Haggen 1"}),
            ),
        )
        db.execute(
            "INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "store_roster",
                "210",
                "United",
                "Andrew Quinn",
                "",
                "2026-09-28",
                "{}",
                json.dumps({"district": "U5"}),
            ),
        )
        db.execute(
            "INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "store_roster",
                "239",
                "Southwest",
                "Ben Sarmadi",
                "",
                "2026-09-28",
                "{}",
                json.dumps({"district": "N0"}),
            ),
        )
        db.execute(
            "INSERT INTO presub_top VALUES (?, ?)",
            ("company", json.dumps([{"name": "Milk", "code": "1", "percent": 3.2, "count": 4}])),
        )
        db.execute(
            "INSERT INTO schedule_pack VALUES (1, '2026-09-28T12:00:00Z', 32, 'week.xlsx', 'Week 31', 468)"
        )
        db.execute("INSERT INTO schedule_market VALUES ('Total', 41.07, 4.03, 88.0)")
        db.execute(
            """
            INSERT INTO schedule_store VALUES (
              '117', 'East Region', 'Shaws', '03', 'Ada', 40000, 20, 1, 50, 70,
              12, 0, 4.2, '[1,null]', '[0,null]'
            )
            """
        )
        db.commit()
        db.close()
        module.extract(str(db_path), str(out))
        home = json.loads((out / "home.json").read_text())
        sales = json.loads((out / "section" / "sales.json").read_text())
        blob = "\n".join(path.read_text() for path in out.rglob("*.json"))
        assert home["publishedAt"] == "2026-09-28T19:10:00Z"
        assert home["metadata"]["schemaVersion"] == module.schema_version()
        assert home["metadata"]["cookSha"] == module.cook_sha()
        assert home["summaries"][0]["health"] == "none"
        assert "Only 36 of 1,297" in home["summaries"][0]["secondary"]
        assert "packs" not in home and "tables" not in home
        stores = {row["store"]: row for row in home["filters"]["stores"]}
        assert "TOTAL" not in stores
        labor = json.loads((out / "section" / "labor.json").read_text())
        assert all(row["store"].upper() != "TOTAL" for row in labor["rows"])
        labor_one = next(row for row in labor["rows"] if row["store"] == "1")
        assert labor_one["payload"]["weight"] == 383
        assert "weight" not in (home.get("laborMarket") or {})
        assert stores["117"]["district"] == "03"
        assert stores["117"]["division"] == "Shaws"
        assert stores["3436"]["district"] == "39"
        assert stores["3436"]["om"] == "Haggen 1"
        assert stores["3436"]["division"] == "Haggen"
        assert stores["210"]["division"] == "United"
        assert stores["210"]["district"] == "U5"
        assert stores["210"]["om"] == "Andrew Quinn"
        assert stores["239"]["division"] == "Southwest"
        assert stores["239"]["district"] == "N0"
        assert stores["239"]["om"] == "Ben Sarmadi"
        sections = {item["section"] for item in home["summaries"]}
        assert "five_star" in sections and "lost_revenue" in sections
        loss = next(item for item in home["summaries"] if item["section"] == "lost_revenue")
        assert loss["headline"] == 869751.99
        lines = home["regionLines"]
        assert lines[0]["region"] == "East" and lines[0]["value"] == "$393,334.12" and lines[0]["count"] == 610
        assert lines[0]["children"][0]["division"] == "Shaws"
        assert lines[0]["children"][0]["value"] == "$1.00"
        assert lines[1]["region"] == "South"
        assert all(line["region"] != "Shaws" for line in lines)
        assert not any(line["title"] == "5 Star" for line in lines)
        schedule = json.loads((out / "schedule.json").read_text())
        assert schedule["summaryTitle"] == "Week 32"
        assert "Week 31" not in schedule["summaryTitle"]
        assert schedule["stores"][0]["store"] == "117"
        assert schedule["stores"][0]["fourUnder"] == 12
        assert schedule["workbookActionBanner"] == 468
        assert schedule["markets"][0]["label"] == "Total"
        assert sales["rows"][0]["payload"] == {"sales_dollars": 1200}
        picker = json.loads((out / "section" / "picker_scorecard.json").read_text())
        assert picker["rows"][0]["shopper"] == "Secret Shopper"
        assert picker["rows"][0]["store"] == "117"
        assert "current.sqlite" not in blob
        assert not (out / "presub.json").read_text().startswith("http")
        print("extract ok")
        absent_schedule_and_item_tab()
        roster_people_stamp()
        path_picker_store_join()


def path_picker_store_join() -> None:
    shoppers = {
        "score-a": {"section": "picker_scorecard", "shopperId": "A", "store": "117"},
        "score-b1": {"section": "picker_scorecard", "shopperId": "B", "store": "118"},
        "score-b2": {"section": "picker_scorecard", "shopperId": "B", "store": "119"},
        "path-a": {"section": "pick_path_picker", "shopperId": "A", "store": ""},
        "path-b": {"section": "pick_path_picker", "shopperId": "B", "store": ""},
        "path-c": {"section": "pick_path_picker", "shopperId": "C", "store": ""},
    }
    attached = module.attach_unique_scorecard_store(shoppers)
    assert attached == 1
    assert shoppers["path-a"]["store"] == "117"
    assert shoppers["path-b"]["store"] == ""
    assert shoppers["path-c"]["store"] == ""
    print("path picker store join ok")


def roster_people_stamp() -> None:
    roster = {
        "210": {"store": "210", "division": "", "district": "", "om": "", "name": ""},
        "1": {"store": "1", "division": "Jewel Osco", "district": "J1", "om": "Chicago 1", "name": ""},
    }
    sales = {"store": "210", "division": "", "district": "", "om": ""}
    people = {
        "210": {"division": "United", "district": "U5", "om": "Andrew Quinn"},
        "1": {"division": "Jewel Osco", "district": "J1", "om": "Shelly Selof"},
    }
    module.apply_roster_people(roster, [sales], people)
    assert sales["om"] == "Andrew Quinn"
    assert sales["division"] == "United"
    assert roster["1"]["om"] == "Shelly Selof"
    assert roster["210"]["om"] == "Andrew Quinn"
    assert "Chicago" not in roster["1"]["om"]
    stray = {"store": "9", "division": "United", "district": "U5", "om": "Andrew Quinn"}
    module.apply_roster_people(roster, [stray], people)
    assert stray["om"] == "Andrew Quinn"
    assert "9" not in roster


def absent_schedule_and_item_tab() -> None:
    """No schedule tables and no item tab stay empty. Chrome dollars stay put."""
    with tempfile.TemporaryDirectory() as tmp:
        db_path = Path(tmp) / "current.sqlite"
        out = Path(tmp) / "out"
        out.mkdir()
        (out / "schedule.json").write_text(
            json.dumps({"stores": [{"store": "9999", "under": 1}]}),
            encoding="utf-8",
        )
        db = sqlite3.connect(db_path)
        db.executescript(
            """
            CREATE TABLE pack_meta (id INTEGER PRIMARY KEY, written_at TEXT);
            CREATE TABLE dash_chrome (id INTEGER PRIMARY KEY, json TEXT NOT NULL);
            CREATE TABLE facts (
              section TEXT, store_number TEXT, division TEXT, operations_om TEXT,
              store_name TEXT, recorded_on TEXT, payload_json TEXT, text_json TEXT
            );
            """
        )
        chrome = {
            "summaries": [
                {
                    "section": "sales",
                    "storeCount": 1,
                    "headline": 37065336.17,
                    "headlineLabel": "eComm sales",
                    "secondary": "",
                    "health": "risk",
                    "watchCount": 0,
                    "riskCount": 1,
                },
                {
                    "section": "lost_revenue",
                    "storeCount": 1,
                    "headline": 1395864.04,
                    "headlineLabel": "Total lost revenue",
                    "secondary": "",
                    "health": "risk",
                    "watchCount": 0,
                    "riskCount": 1,
                },
            ],
            "packs": {},
        }
        db.execute("INSERT INTO pack_meta VALUES (1, '2026-09-30T18:23:22Z')")
        db.execute("INSERT INTO dash_chrome VALUES (1, ?)", (json.dumps(chrome),))
        db.execute(
            "INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "sales",
                "",
                "",
                "",
                "",
                "2026-09-30",
                json.dumps({"sales_dollars": 1, "sales_yoy_pct": -99}),
                json.dumps({"sales_grain": "company"}),
            ),
        )
        db.commit()
        db.close()
        module.extract(str(db_path), str(out))
        home = json.loads((out / "home.json").read_text())
        sales = json.loads((out / "section" / "sales.json").read_text())
        assert home["publishedAt"] == "2026-09-30T18:23:22Z"
        assert home["preSubItemTabPresent"] is False
        schedule = json.loads((out / "schedule.json").read_text())
        assert schedule["empty"] is True
        assert schedule["stores"] == []
        assert schedule["markets"] == []
        assert "9999" not in (out / "schedule.json").read_text()
        loss = next(item for item in home["summaries"] if item["section"] == "lost_revenue")
        company = next(item for item in home["summaries"] if item["section"] == "sales")
        assert loss["headline"] == 1395864.04
        assert company["headline"] == 37065336.17
        assert sales["rows"] == []
        print("absent schedule ok")


def raw_sheet_divisions() -> None:
    """Missing Items and Schedule Quality sheets use DENVER / JEWEL. Rows use the roster name."""
    assert module.canonical_division("DENVER") == "Mountain West"
    assert module.canonical_division("INTERMOUNTAIN") == "Mountain West"
    assert module.canonical_division("JEWEL") == "Jewel Osco"
    assert module.canonical_division("SO CALIFORNIA") == "SoCal"
    with tempfile.TemporaryDirectory() as tmp:
        db_path = Path(tmp) / "current.sqlite"
        out = Path(tmp) / "out"
        db = sqlite3.connect(db_path)
        db.executescript(
            """
            CREATE TABLE pack_meta (id INTEGER PRIMARY KEY, written_at TEXT);
            CREATE TABLE dash_chrome (id INTEGER PRIMARY KEY, json TEXT NOT NULL);
            CREATE TABLE facts (
              section TEXT, store_number TEXT, division TEXT, operations_om TEXT,
              store_name TEXT, recorded_on TEXT, payload_json TEXT, text_json TEXT
            );
            """
        )
        chrome = {
            "publishedAt": "2026-10-06T01:35:23Z",
            "summaries": [],
            "packs": {
                "missing_items": [
                    {
                        "line": {"label": "West Region", "value": "8.0%", "count": 2, "health": "watch"},
                        "children": [
                            {"label": "DENVER", "value": "7.0%", "count": 1, "health": "watch"},
                            {"label": "INTERMOUNTAIN", "value": "9.0%", "count": 1, "health": "watch"},
                        ],
                    }
                ],
                "schedule_quality": [
                    {
                        "line": {"label": "East Region", "value": "90%", "count": 1, "health": "good"},
                        "children": [{"label": "JEWEL", "value": "91%", "count": 1, "health": "good"}],
                    }
                ],
            },
        }
        db.execute("INSERT INTO pack_meta VALUES (1, '2026-10-06T01:35:23Z')")
        db.execute("INSERT INTO dash_chrome VALUES (1, ?)", (json.dumps(chrome),))
        rows = [
            ("store_roster", "879", "Mountain West", "Ellas Ware", "66"),
            ("store_roster", "4799", "Jewel Osco", "Mike Macdonald", "J6"),
            ("missing_items", "879", "DENVER", "sheet om", "65"),
            ("missing_items", "339", "INTERMOUNTAIN", "", "I5"),
            ("schedule_quality", "4799", "JEWEL", "sheet om", "J6"),
            ("pph", "339", "Mountain West", "Chris Banuelos", "I5"),
        ]
        for section, store, division, om, district in rows:
            db.execute(
                "INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (section, store, division, om, "", "2026-10-06", "{}", json.dumps({"district": district})),
            )
        db.commit()
        db.close()
        module.extract(str(db_path), str(out))
        missing = json.loads((out / "section" / "missing_items.json").read_text())["rows"]
        quality = json.loads((out / "section" / "schedule_quality.json").read_text())["rows"]
        by_store = {row["store"]: row["division"] for row in missing}
        assert by_store["879"] == "Mountain West"
        assert by_store["339"] == "Mountain West"
        assert {row["store"]: row["division"] for row in quality}["4799"] == "Jewel Osco"
        home = json.loads((out / "home.json").read_text())
        labels = []
        for line in home["regionLines"]:
            if line["section"] not in {"missing_items", "schedule_quality"}:
                continue
            labels.extend(child["division"] for child in line["children"])
        assert "DENVER" not in labels
        assert "INTERMOUNTAIN" not in labels
        assert "JEWEL" not in labels
        assert "Mountain West" in labels
        assert "Jewel Osco" in labels
        print("raw sheet divisions ok")


def blank_schedule_ok() -> None:
    schedule = {
        "markets": [{"label": "United", "under": None, "over": None, "eff": 100.0}],
        "stores": [
            {
                "store": "22",
                "under": 0.0,
                "over": 0.0,
                "eff": 100.0,
                "pch": None,
                "fourUnder": None,
                "fourOver": None,
                "dayUnder": [None] * 7,
                "dayOver": [None] * 7,
            },
            {"store": "117", "under": 12.0, "over": 3.0, "eff": 80.0, "pch": 70, "fourUnder": 4, "fourOver": 1, "dayUnder": [1], "dayOver": [None]},
        ],
    }
    module.clear_blank_schedule(schedule)
    assert schedule["stores"][0]["under"] is None
    assert schedule["stores"][0]["eff"] is None
    assert schedule["markets"][0]["eff"] is None
    assert schedule["stores"][1]["under"] == 12.0
    assert "eot_capacity" in module.KEEP and "used_capacity" in module.KEEP
    print("blank schedule ok")


def off_roster_loss_ok() -> None:
    import openpyxl

    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "daily.xlsx"
        book = openpyxl.Workbook()
        sheet = book.active
        sheet.title = "Loss Revenue"
        sheet.append(
            [
                "Store",
                "First DIVISION",
                "eComm Sales",
                "Total Lost Revenue (Total Opportunity)",
                "Total Lost Revenue % (Total Opportunity)",
                "Total Lost Revenue (FY2026 Goal)",
                "Total Lost Revenue (FY2026 Goal) %",
                "Capacity Reduction (Total Opportunity)",
                "Total Reduced Capacity",
            ]
        )
        sheet.append(["210", "Haggen", 3545.2, 263, 0.07418481326864493, 181.0755, 0.051076243935462035, None, None])
        sheet.append(["1", "Haggen", 100, 10, 0.1, 4, 0.04, 10.5, 4])
        sheet.append(["1509", "Haggen", 349.72, 0, 0, None, None, None, None])
        sheet.append(["Total", "Haggen", 80, 20, 0.05, 10, 0.03, 420030.8708321518, 178705.37])
        book.save(path)
        book.close()
        rows = module.read_loss_sheet(str(path))
        assert [row["store"] for row in rows] == ["210", "1", "1509"]
        assert rows[2]["payload"].get("lost_revenue_goal_pct") is None
        latest = {
            ("lost_revenue", "1"): {
                "store": "1",
                "division": "Jewel Osco",
                "district": "J1",
                "om": "Shelly Selof",
                "payload": {"lost_revenue": 3530},
                "section": "lost_revenue",
            },
            ("lost_revenue", "1509"): {
                "store": "1509",
                "division": "Mountain West",
                "district": "I5",
                "om": "Chris Banuelos",
                "payload": {"lost_revenue": 0, "ecomm_sales": 349.72},
                "section": "lost_revenue",
            },
        }
        roster = {
            "210": {"store": "210", "division": "United", "district": "U5", "om": "Andrew Quinn", "name": ""},
        }
        added, company_missed = module.merge_off_roster_loss(latest, roster, str(path))
        assert added == 1
        assert company_missed == 420030.8708321518
        kept = latest[("lost_revenue", "210")]
        assert kept["division"] == "United"
        assert kept["division"] != "Haggen"
        assert kept["payload"]["lost_revenue"] == 263
        assert "missed_sales" not in kept["payload"]
        assert latest[("lost_revenue", "1")]["division"] == "Jewel Osco"
        assert latest[("lost_revenue", "1")]["payload"]["lost_revenue"] == 3530
        assert latest[("lost_revenue", "1")]["payload"]["missed_sales"] == 10.5
        assert "lost_revenue_goal_pct" not in latest[("lost_revenue", "1509")]["payload"]
        assert "missed_sales" not in latest[("lost_revenue", "1509")]["payload"]
        print("off roster loss ok")


if __name__ == "__main__":
    main()
    raw_sheet_divisions()
    blank_schedule_ok()
    off_roster_loss_ok()
