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
                json.dumps({"act_hrs": 383, "act_cost_dollar": 6181, "aiv_impact_pct": -0.38645958215580284, "cost_trgt_pct": 11.4}),
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
        assert labor_one["payload"]["act_cost_dollars"] == 6181
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
        sales_line = next(line for line in lines if line["section"] == "sales")
        assert sales_line["region"] == "East"
        assert sales_line["value"] == "$1,200.00"
        assert sales_line["count"] == 1
        assert sales_line["children"][0]["division"] == "Shaws"
        assert sales_line["children"][0]["value"] == "$1,200.00"
        assert all(line["value"] != "$393,334.12" for line in lines)
        sales_table = next(row for row in home["regionTables"] if row["section"] == "sales")
        assert sales_table["region"] == "East"
        assert sales_table["headline"] == "$1,200.00"
        assert sales_table["storeCount"] == 1
        rollups = home["pickerRollups"]
        assert rollups["company"]["shoppers"] == 1
        assert rollups["company"]["stores"] == 1
        assert rollups["store:117"]["shoppers"] == 1
        assert "region:East Region" in rollups
        assert home["metadata"]["cookedAt"] == home["cookedAt"]
        assert loss["storeCount"] == 0
        assert all(line["region"] != "Shaws" for line in lines)
        assert not any(line["title"] == "5 Star" for line in lines)
        schedule = json.loads((out / "schedule.json").read_text())
        assert home["cookedAt"] == sales["cookedAt"] == schedule["cookedAt"]
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
        payloads = {
            "missing_items": {"mi_pct": 8},
            "schedule_quality": {"schedule_efficiency_pct": 90},
        }
        for section, store, division, om, district in rows:
            db.execute(
                "INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    section,
                    store,
                    division,
                    om,
                    "",
                    "2026-10-06",
                    json.dumps(payloads.get(section) or {}),
                    json.dumps({"district": district}),
                ),
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


def lost_excl_rollup() -> None:
    records = [
        {"section": "lost_revenue", "store": "1", "division": "Shaws", "payload": {"lost_revenue": 100, "missed_sales": 10}},
        {"section": "lost_revenue", "store": "210", "division": "United", "payload": {"lost_revenue": 263}},
        {"section": "lost_revenue", "store": "239", "division": "Southwest", "payload": {"lost_revenue": 239.4, "missed_sales": 0}},
        {"section": "sales", "store": "1", "division": "Shaws", "payload": {"sales_dollars": 5}},
    ]
    lines = module.realign_lost_revenue(
        [{"section": "lost_revenue", "region": "East", "title": "Loss", "value": "$9.00", "count": 1, "children": []}],
        records,
    )
    by_region = {line["region"]: line for line in lines if line["section"] == "lost_revenue"}
    assert set(by_region) == {"East", "South"}
    assert by_region["East"]["title"] == "Lost $ excl. Missed"
    assert by_region["East"]["value"] == "$90.00"
    assert by_region["East"]["count"] == 1
    assert by_region["East"]["missed"] == "Not available"
    assert by_region["East"]["children"][0]["division"] == "Shaws"
    assert by_region["East"]["children"][0]["missed"] == "Not available"
    assert by_region["South"]["value"] == "$502.40"
    assert by_region["South"]["count"] == 2
    tables = [
        {"section": "lost_revenue", "region": "South", "title": "Lost Revenue", "headline": "$779,589.702", "storeCount": 395},
        {"section": "sales", "region": "South", "title": "Sales", "headline": "$1.00", "storeCount": 1},
    ]
    module.sync_lost_region_tables(tables, lines)
    assert tables[0]["title"] == "Lost $ excl. Missed"
    assert tables[0]["headline"] == "$502.40"
    assert tables[0]["storeCount"] == 2
    assert tables[1]["headline"] == "$1.00"
    home = {
        "companyTiles": {"lost_revenue": {"labels": ["Lost $", "Kill"], "values": ["$4,248,638.426", "$19,812.555"]}},
        "regionLines": lines,
        "regionTables": tables,
    }
    module.round_pack_currency(home)
    assert home["companyTiles"]["lost_revenue"]["values"] == ["$4,248,638.43", "$19,812.56"]
    assert home["regionTables"][0]["headline"] == "$502.40"
    summaries = [
        {"section": "lost_revenue", "storeCount": 2165, "secondary": "2,165 stores reported · 9/27"},
        {"section": "missing_items", "storeCount": 2165},
        {"section": "five_star", "storeCount": 2165},
        {"section": "pre_sub_oos", "storeCount": 2165},
        {"section": "sales", "storeCount": 9},
    ]
    latest = {
        ("lost_revenue", "210"): {},
        ("lost_revenue", "239"): {},
        ("missing_items", "210"): {},
        ("five_star", "1"): {},
        ("pre_sub_oos", "1"): {},
        ("pre_sub_oos", "2"): {},
    }
    shoppers = {
        "a": {"section": "picker_scorecard", "store": "210"},
        "b": {"section": "picker_scorecard", "store": "210"},
        "c": {"section": "picker_scorecard", "store": "239"},
    }
    rollups = {"company": {"stores": 2165, "shoppers": 3}}
    module.apply_own_store_counts(summaries, latest, shoppers, rollups)
    counted = {item["section"]: item["storeCount"] for item in summaries}
    assert counted["lost_revenue"] == 2
    assert summaries[0]["secondary"] == "2 stores reported · 9/27"
    assert counted["missing_items"] == 1
    assert counted["five_star"] == 1
    assert counted["pre_sub_oos"] == 2
    assert counted["sales"] == 9
    assert rollups["company"]["stores"] == 2
    assert rollups["company"]["shoppers"] == 3
    print("lost excl rollup ok")


def pack_identity_choice() -> None:
    import importlib.util

    spec = importlib.util.spec_from_file_location("pack_identity", ROOT / "pack_identity.py")
    choice = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(choice)
    fresh = {"cookSha": "a" * 40, "cookedAt": "2026-10-07T01:00:00Z", "errors": []}
    have = {"cookSha": "b" * 40, "cookedAt": "", "errors": []}
    assert choice.prefer(fresh, have) == "refuse"
    pinned_disk = {
        "cookSha": "74d44dde02a0e1c6430a9a78b06034099c84e001",
        "cookedAt": "",
        "publishedAt": "2026-10-06T01:35:23Z",
        "errors": [],
    }
    assert choice.prefer(fresh, pinned_disk) == "replace"
    assert choice.prefer(
        fresh,
        {**pinned_disk, "publishedAt": "2026-10-07T00:00:00Z"},
    ) == "refuse"
    assert choice.prefer(fresh, {**pinned_disk, "publishedAt": ""}) == "refuse"
    assert choice.prefer(fresh, {"cookSha": "a" * 40, "cookedAt": "2026-10-07T02:00:00Z", "errors": []}) == "keep"
    assert choice.prefer(
        {"cookSha": "a" * 40, "cookedAt": "", "errors": []},
        {"cookSha": "b" * 40, "cookedAt": "2026-10-07T01:00:00Z", "errors": []},
    ) == "refuse"
    pinned = "74d44dde02a0e1c6430a9a78b06034099c84e001"
    assert choice.prefer(
        {"cookSha": pinned, "cookedAt": "", "errors": []},
        {"cookSha": pinned, "cookedAt": "", "errors": []},
    ) == "refuse"
    assert choice.prefer(
        {"cookSha": "e" * 40, "cookedAt": "", "errors": []},
        {"cookSha": "e" * 40, "cookedAt": "", "errors": []},
    ) == "refuse"
    assert choice.prefer(fresh, {"cookSha": fresh["cookSha"], "cookedAt": fresh["cookedAt"], "errors": []}) == "keep"
    later = {"cookSha": "a" * 40, "cookedAt": "2026-10-07T03:00:00Z", "errors": []}
    earlier = {"cookSha": "b" * 40, "cookedAt": "2026-10-07T01:00:00Z", "errors": []}
    assert choice.newer(later, earlier) == "refuse"
    assert choice.newer(later, earlier, lambda sha: sha == later["cookSha"]) == "fetch"
    assert choice.newer(
        {"cookSha": "c" * 40, "cookedAt": "", "errors": []},
        {"cookSha": "d" * 40, "cookedAt": "", "errors": []},
    ) == "refuse"
    assert choice.newer(
        {"cookSha": "a" * 40, "cookedAt": "", "publishedAt": "2026-10-07T00:00:00Z", "errors": []},
        {"cookSha": "a" * 40, "cookedAt": "2026-10-07T01:00:00Z", "errors": []},
    ) == "refuse"
    assert choice.newer(
        {"cookSha": pinned, "cookedAt": "", "publishedAt": "2026-10-06T01:35:23Z", "errors": []},
        {"cookSha": "a" * 40, "cookedAt": "2026-10-07T01:00:00Z", "errors": []},
    ) == "keep"
    assert choice.newer(
        {"cookSha": pinned, "cookedAt": "", "errors": []},
        {"cookSha": pinned, "cookedAt": "", "errors": []},
    ) == "refuse"
    pinned_both = {
        "cookSha": pinned,
        "cookedAt": "",
        "publishedAt": "2026-10-06T01:35:23Z",
        "errors": [],
    }
    assert choice.newer(pinned_both, pinned_both) == "keep"
    newer_local = {"cookSha": "a" * 40, "cookedAt": "2026-10-07T04:00:00Z", "errors": []}
    older_local = {"cookSha": "b" * 40, "cookedAt": "2026-10-07T01:00:00Z", "errors": []}
    assert choice.live_against(older_local, newer_local, lambda sha: True) == "keep"
    assert choice.live_against(newer_local, older_local, lambda sha: True) == "refuse"
    assert choice.newer(
        {"cookSha": "e" * 40, "cookedAt": "", "errors": []},
        {"cookSha": "e" * 40, "cookedAt": "", "errors": []},
    ) == "refuse"
    live_pack = choice.load_identity(ROOT.parent / "public" / "data")
    assert live_pack["errors"] == []
    assert live_pack["cookSha"] == pinned
    assert live_pack["publishedAt"] == "2026-10-06T01:35:23Z"
    assert live_pack["cookedAt"] == ""
    assert choice.prefer(fresh, live_pack) == "replace"
    with tempfile.TemporaryDirectory() as tmp:
        disagree = Path(tmp)
        (disagree / "a.json").write_text(
            json.dumps({"cookSha": pinned, "publishedAt": "2026-10-06T01:35:23Z"}),
            encoding="utf-8",
        )
        (disagree / "b.json").write_text(
            json.dumps({"cookSha": pinned, "publishedAt": "2026-10-07T00:00:00Z"}),
            encoding="utf-8",
        )
        split = choice.load_identity(disagree)
    assert split["errors"]
    assert split["publishedAt"] == ""
    print("pack identity ok")


def _synthetic_workbook(path: Path, total_row: int) -> None:
    """Tiny workbook. Total sits on total_row, with an earlier Total the cook must ignore."""
    import zipfile

    sheets = {
        "Sales": {"CH": 81000, "CI": 0.17, "CK": 0.18},
        "Loss Revenue": {"C": 82000, "D": 4200, "J": 2900, "M": 590, "V": 420, "Y": 270, "AC": 19},
        "Labor": {"B": 0.88, "I": 1800, "J": 0.11, "K": -0.04, "L": 0.001, "M": 0.00002, "N": 0.07, "O": -0.04},
        "MI": {"U": 0.07},
        "Pre-Sub OOS": {"P": 0.05},
        "Schedule Quality": {"D": 0.9, "E": 0.04, "F": 0.05, "J": 0.73},
        "Pick Path": {"E": 0.8, "G": 75},
        "Dynacap": {"D": 63, "G": 0.22},
        "PPH": {"T": 73},
    }
    decoy = {"CH": 1, "CI": 1, "CK": 1, "C": 1, "D": 1, "J": 1, "M": 1, "V": 1, "Y": 1, "AC": 1, "B": 1, "I": 1, "K": 1, "L": 1, "N": 1, "O": 1, "U": 1, "P": 1, "E": 1, "F": 1, "G": 1, "T": 1}

    def row_xml(number: int, cells: dict) -> str:
        body = "".join(cells)
        return f'<row r="{number}">{body}</row>'

    def num(ref: str, value) -> str:
        return f'<c r="{ref}"><v>{value}</v></c>'

    def total_label(ref: str) -> str:
        return f'<c r="{ref}" t="s"><v>0</v></c>'

    sheet_xml = {}
    for index, (name, fields) in enumerate(sheets.items(), start=1):
        early = [total_label(f"A3")] + [num(f"{col}3", decoy[col]) for col in fields]
        late = [total_label(f"A{total_row}")] + [num(f"{col}{total_row}", value) for col, value in fields.items()]
        stores = ""
        if name == "Labor":
            stores = row_xml(2, [num("A2", 10)]) + row_xml(4, [num("A4", 866)])
        sheet_xml[index] = (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
            + row_xml(3, early)
            + stores
            + row_xml(total_row, late)
            + "</sheetData></worksheet>"
        )
    names = list(sheets)
    sheet_tags = "".join(
        f'<sheet name="{name}" sheetId="{index}" r:id="rId{index}"/>' for index, name in enumerate(names, start=1)
    )
    rels = "".join(
        f'<Relationship Id="rId{index}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{index}.xml"/>'
        for index in range(1, len(names) + 1)
    )
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr(
            "xl/sharedStrings.xml",
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>Total</t></si></sst>',
        )
        archive.writestr(
            "xl/workbook.xml",
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            f"<sheets>{sheet_tags}</sheets></workbook>",
        )
        archive.writestr(
            "xl/_rels/workbook.xml.rels",
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            f"{rels}</Relationships>",
        )
        for index, xml in sheet_xml.items():
            archive.writestr(f"xl/worksheets/sheet{index}.xml", xml)


def workbook_total_sources() -> None:
    import math
    import os

    from workbook_totals import labor_store_ids, read_workbook_totals

    parser = (ROOT.parents[1] / "FulfillmentHeartbeat" / "Storage" / "WorkbookParser.swift").read_text(encoding="utf-8")
    assert "include: nil" in parser
    assert "columnLooksLikeStore(data" not in parser
    path = os.environ.get("HEARTBEAT_DAILY_XLSX") or "/tmp/hb-icloud/Heartbeat Daily Report.xlsx"
    if not Path(path).is_file():
        print(f"workbook totals skipped: {path} is absent")
        return
    got = read_workbook_totals(path)
    expected = {
        "sales": {
            "sales_dollars": 81833890.57000001,
            "yoy_pct": 0.17156333213937902,
            "orders_yoy_pct": 0.17823178138047124,
        },
        "lost_revenue": {
            "ecomm_dollars": 81865991.14999996,
            "lost_dollars": 4248638.425832152,
            "post_sub_dollars": 2944950.0,
            "refund_dollars": 591545.0,
            "missed_dollars": 420030.8708321518,
            "cancel_dollars": 272300.0,
            "kill_dollars": 19812.555000000004,
        },
        "labor": {
            "schedule_efficiency_pct": 0.8822231683849824,
            "act_cost_dollars": 18849844.0,
            "cost_trgt_pct": 0.11810996221455011,
            "uplh_impact_pct": -0.04150171707252105,
            "wage_impact_pct": 0.0008531258417799059,
            "aiv_impact_pct": 2.610916545167652e-05,
            "act_cost_pct": 0.07748748014926157,
            "target_vs_actual_pct": -0.04062248206528947,
        },
        "missing_items": {"missing_rate": 0.07553722973090837},
        "pre_sub_oos": {"pre_sub_rate": 0.055682480841363624},
        "schedule_quality": {
            "schedule_efficiency_pct": 0.8996549831038603,
            "under_schedule_pct": 0.043122082616643714,
            "over_schedule_pct": 0.05722293427949598,
            "staffing_efficiency_pct": 0.7352512606590209,
        },
        "pick_path": {"compliance_pct": 0.8021088294904692, "pph": 75.45866087242787},
        "dynacap": {"pieces_per_hour": 63.14703661811971, "utilization_pct": 0.22439931464860194},
        "pph": {"pph": 73.50856886797969},
    }
    schema = (ROOT.parent / "public" / "schema.js").read_text(encoding="utf-8")
    assert "WORKBOOK_TOTAL_FIELDS" in schema
    for section, fields in expected.items():
        assert section in schema
        for name, value in fields.items():
            assert name in schema
            assert math.isclose(got[section][name], value, rel_tol=1e-9, abs_tol=1e-9), (section, name, got[section][name], value)
    stores = labor_store_ids(path)
    assert len(stores) == 2169, len(stores)
    for store in ["10", "23", "24", "25", "28", "31", "33", "42", "62", "63", "65", "66", "72", "73", "76", "91", "93", "94"]:
        assert store in stores, store
    print("workbook totals ok")


def workbook_total_shifted_row() -> None:
    """The Total row is found by its label, including after extract writes home.workbookTotal."""
    from workbook_totals import labor_store_ids, read_workbook_totals

    with tempfile.TemporaryDirectory() as tmp:
        book = Path(tmp) / "daily.xlsx"
        _synthetic_workbook(book, 40)
        got = read_workbook_totals(book)
        assert got["sales"]["sales_dollars"] == 81000
        assert got["sales"]["sales_dollars"] != 1
        assert got["pph"]["pph"] == 73
        assert got["labor"]["act_cost_pct"] == 0.07
        assert got["lost_revenue"]["kill_dollars"] == 19
        stores = labor_store_ids(book)
        assert stores == ["10", "866"], stores
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
        db.execute("INSERT INTO pack_meta VALUES (1, '2026-10-07T00:00:00Z')")
        db.execute(
            "INSERT INTO dash_chrome VALUES (1, ?)",
            (
                json.dumps(
                    {
                        "publishedAt": "2026-10-06T01:35:23Z",
                        "summaries": [],
                        "companyTiles": {
                            "lost_revenue": {
                                "labels": ["Lost $", "Missed"],
                                "values": ["$1.00", "$9.00"],
                            }
                        },
                    }
                ),
            ),
        )
        db.commit()
        db.close()
        originals = (module.merge_off_roster_loss, module.read_roster_people)
        module.merge_off_roster_loss = lambda latest, roster, path: (0, None)
        module.read_roster_people = lambda path: {}
        try:
            module.extract(str(db_path), str(out), str(book))
        finally:
            module.merge_off_roster_loss, module.read_roster_people = originals
        home = json.loads((out / "home.json").read_text())
        assert home["workbookTotal"]["sales"]["sales_dollars"] == 81000
        assert home["workbookTotal"]["labor"]["act_cost_dollars"] == 1800
        assert home["workbookTotal"]["dynacap"]["pieces_per_hour"] == 63
        missed = home["companyTiles"]["lost_revenue"]
        assert missed["values"][missed["labels"].index("Missed")] == "$420.00"
        assert home["workbookTotal"]["lost_revenue"]["missed_dollars"] == 420
    print("workbook total shift ok")


def labor_blanks_are_null() -> None:
    """Store 866's blank ActCost% is null, not the 0 that cost + target-vs-actual used to invent."""
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
        db.execute("INSERT INTO pack_meta VALUES (1, '2026-10-07T00:00:00Z')")
        db.execute(
            "INSERT INTO dash_chrome VALUES (1, ?)",
            (json.dumps({"publishedAt": "2026-10-06T01:35:23Z", "summaries": []}),),
        )
        db.execute(
            "INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "labor",
                "866",
                "Mid-Atlantic",
                "Quyen Truong",
                "",
                "2026-10-07",
                json.dumps(
                    {
                        "schedule_efficiency_pct": 91.6,
                        "sch_hrs": 122,
                        "cost_trgt_pct": 247.99,
                        "target_vs_actual_pct": -247.99,
                        "uplh_impact_pct": -247.99,
                        "act_hrs": "",
                        "act_cost_dollar": None,
                    }
                ),
                json.dumps({"labor_grain": "store", "district": "87"}),
            ),
        )
        db.execute(
            "INSERT INTO facts VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "labor",
                "1",
                "Jewel Osco",
                "Ada",
                "",
                "2026-10-07",
                json.dumps(
                    {
                        "act_cost_pct": 0,
                        "act_hrs": 0,
                        "act_cost_dollars": 0,
                        "cost_trgt_pct": 0,
                    }
                ),
                json.dumps({"labor_grain": "store", "district": "01"}),
            ),
        )
        db.commit()
        db.close()
        module.extract(str(db_path), str(out))
        labor = json.loads((out / "section" / "labor.json").read_text())
        rows = {row["store"]: row["payload"] for row in labor["rows"]}
        blank = rows["866"]
        assert blank["act_cost_pct"] is None, blank
        assert blank["act_hrs"] is None, blank
        assert blank["act_cost_dollars"] is None, blank
        assert blank["cost_trgt_pct"] == 247.99
        assert "weight" not in blank
        zero = rows["1"]
        assert zero["act_cost_pct"] == 0
        assert zero["act_hrs"] == 0
        assert zero["act_cost_dollars"] == 0
        assert zero["cost_trgt_pct"] == 0
        assert zero["weight"] == 0
    print("labor blanks ok")


def _pack_section_records(section: str) -> list:
    blob = json.loads((ROOT.parent / "public" / "data" / "section" / f"{section}.json").read_text())
    records = []
    for row in blob["rows"]:
        records.append(
            {
                "section": section,
                "store": row.get("store") or "",
                "division": row.get("division") or "",
                "district": row.get("district") or "",
                "om": row.get("om") or "",
                "shopper": row.get("shopper") or "",
                "shopperId": row.get("shopperId") or "",
                "payload": row.get("payload") or {},
                "sourceIssue": row.get("sourceIssue"),
            }
        )
    return records


def region_rows_cover_company() -> None:
    """Region lines, tables, and picker rollups come from store rows, not the old device pack."""
    records = [
        {"section": "sales", "store": "210", "division": "United", "payload": {"sales_dollars": 3545.20}},
        {"section": "sales", "store": "239", "division": "Southwest", "payload": {"sales_dollars": 7324.64}},
        {"section": "sales", "store": "1", "division": "NorCal", "payload": {"sales_dollars": 100}},
        {"section": "pre_sub_oos", "store": "210", "division": "United", "payload": {"mi_pct": 4}},
        {"section": "pre_sub_oos", "store": "239", "division": "Southwest", "payload": {"mi_pct": 6}},
        {"section": "picker_scorecard", "store": "210", "division": "United", "district": "U5", "om": "Andrew Quinn", "shopperId": "A", "payload": {"pph": 90}},
        {"section": "picker_scorecard", "store": "210", "division": "United", "district": "U5", "om": "Andrew Quinn", "shopperId": "A", "payload": {"pph": 50}},
        {"section": "picker_scorecard", "store": "239", "division": "Southwest", "district": "N0", "om": "Ben Sarmadi", "shopperId": "B", "payload": {"pph": 70}},
        {"section": "labor", "store": "10", "division": "Shaws", "payload": {"target_vs_actual_pct": -10}},
        {"section": "labor", "store": "11", "division": "Shaws", "payload": {"target_vs_actual_pct": -2}},
    ]
    lines, tables = module.build_region_views(records)
    module.assert_additive_region_sums(
        lines,
        records,
        {"sales": {"sales_dollars": 3545.20 + 7324.64 + 100}},
    )
    by = {(line["section"], line["region"]): line for line in lines}
    south = by[("sales", "South")]
    assert south["value"] == "$10,869.84"
    assert south["count"] == 2
    kids = {child["division"]: child for child in south["children"]}
    assert kids["United"]["value"] == "$3,545.20"
    assert kids["Southwest"]["value"] == "$7,324.64"
    assert by[("sales", "California")]["value"] == "$100.00"
    assert by[("sales", "California")]["count"] == 1
    assert by[("pre_sub_oos", "South")]["value"] == "5.00%"
    assert by[("pre_sub_oos", "South")]["count"] == 2
    assert by[("labor", "East")]["value"] == "-6.00%"
    assert by[("picker_scorecard", "South")]["value"] == "2 shoppers"
    assert by[("picker_scorecard", "South")]["count"] == 2
    roll = module.build_picker_rollups(records)
    assert roll["company"]["shoppers"] == 2
    assert roll["company"]["stores"] == 2
    assert roll["store:210"]["shoppers"] == 1
    assert roll["store:210"]["risk"] == 1
    assert roll["region:South Region"]["shoppers"] == 2
    table = {(row["section"], row["region"]): row for row in tables}
    assert table[("sales", "South")]["headline"] == "$10,869.84"
    assert table[("sales", "South")]["storeCount"] == 2
    assert table[("picker_scorecard", "South")]["headline"] == "2"
    assert table[("labor", "East")]["headline"] == "-6.00%"
    orphan = records + [{"section": "sales", "store": "9", "division": "", "payload": {"sales_dollars": 50}}]
    try:
        module.assert_additive_region_sums(module.build_region_views(orphan)[0], orphan)
    except SystemExit as exc:
        assert "outside a region" in str(exc)
    else:
        raise AssertionError("orphan sales should fail")

    pinned = []
    for section in ("sales", "lost_revenue", "picker_scorecard"):
        pinned.extend(_pack_section_records(section))
    pinned_lines, pinned_tables = module.build_region_views(pinned)
    module.assert_additive_region_sums(
        pinned_lines,
        pinned,
        {"sales": {"sales_dollars": 81833890.57}},
    )
    pinned_sales = {(line["region"]): line for line in pinned_lines if line["section"] == "sales"}
    assert pinned_sales["South"]["value"] == "$14,749,116.96"
    assert pinned_sales["South"]["count"] == 397
    assert pinned_sales["California"]["value"] == "$23,804,503.18"
    assert pinned_sales["California"]["count"] == 601
    total = sum(module._parse_money(line["value"]) for line in pinned_sales.values())
    assert abs(total - 81833890.57) <= 0.05
    south_kids = {child["division"]: child for child in pinned_sales["South"]["children"]}
    assert south_kids["United"]["count"] == 71
    east_kids = {child["division"]: child for child in pinned_sales["East"]["children"]}
    assert east_kids["Jewel Osco"]["count"] == 180
    west_kids = {child["division"]: child for child in pinned_sales["West"]["children"]}
    assert west_kids["Mountain West"]["count"] == 195
    assert west_kids["Seattle"]["count"] == 212
    pinned_table = {(row["section"], row["region"]): row for row in pinned_tables}
    assert pinned_table[("sales", "South")]["headline"] == "$14,749,116.96"
    assert pinned_table[("sales", "South")]["storeCount"] == 397
    assert pinned_table[("lost_revenue", "South")]["title"] == "Lost $ excl. Missed"
    rollups = module.build_picker_rollups(pinned)
    company = rollups["company"]
    assert company["stores"] == 2167
    assert company["healthy"] + company["watch"] + company["risk"] == company["shoppers"]
    assert rollups["store:210"]["shoppers"] == 6
    assert rollups["store:239"]["shoppers"] > 0
    assert "region:South Region" in rollups
    print("region rows ok")


if __name__ == "__main__":
    main()
    raw_sheet_divisions()
    blank_schedule_ok()
    off_roster_loss_ok()
    lost_excl_rollup()
    pack_identity_choice()
    workbook_total_sources()
    workbook_total_shifted_row()
    labor_blanks_are_null()
    region_rows_cover_company()
