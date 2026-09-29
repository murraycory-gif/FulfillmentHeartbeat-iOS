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
                }
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
            "packs": {"huge": [{"line": {"label": "do-not-copy"}}]},
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
            "INSERT INTO presub_top VALUES (?, ?)",
            ("company", json.dumps([{"name": "Milk", "code": "1", "percent": 3.2, "count": 4}])),
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
        assert home["filters"]["stores"][0]["store"] == "117"
        assert home["filters"]["stores"][0]["district"] == "03"
        assert sales["rows"][0]["payload"] == {"sales_dollars": 1200}
        assert "Secret Shopper" not in blob
        assert "current.sqlite" not in blob
        assert not (out / "presub.json").read_text().startswith("http")
        print("extract ok")


if __name__ == "__main__":
    main()
