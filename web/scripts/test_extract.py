#!/usr/bin/env python3
"""Synthetic company seat. Confirms the web pack drops shopper rows and sqlite."""

import json
import sqlite3
import tempfile
from pathlib import Path

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
        assert home["summaries"][0]["health"] == "none"
        assert "Only 36 of 1,297" in home["summaries"][0]["secondary"]
        assert "packs" not in home and "tables" not in home
        stores = {row["store"]: row for row in home["filters"]["stores"]}
        assert stores["117"]["district"] == "03"
        assert stores["117"]["division"] == "Shaws"
        assert stores["3436"]["district"] == "39"
        assert stores["3436"]["om"] == "Haggen 1"
        assert stores["3436"]["division"] == "Haggen"
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
    assert stray["om"] == ""
    assert roster["9"]["om"] == "" if "9" in roster else True


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


if __name__ == "__main__":
    main()
