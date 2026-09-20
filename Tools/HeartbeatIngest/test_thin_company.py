#!/usr/bin/env python3
"""KEEP/DROP fixture for thin_company. No needs_attention. Cook/thin only."""
from __future__ import annotations

import json
import os
import sqlite3
import tempfile
import unittest
from pathlib import Path

import thin_company as thin


def _write_pack(path: str, *, scorecard_n: int, haggen_only: bool, chrome_shoppers: int) -> None:
    con = sqlite3.connect(path)
    con.execute(
        """CREATE TABLE facts (
            id TEXT PRIMARY KEY, section TEXT NOT NULL, store_number TEXT NOT NULL,
            division TEXT, operations_om TEXT, store_name TEXT, recorded_on TEXT,
            payload_json TEXT, text_json TEXT
        )"""
    )
    con.execute("CREATE TABLE dash_chrome (id INTEGER PRIMARY KEY, json TEXT NOT NULL)")
    con.execute("CREATE TABLE pack_meta (id INTEGER PRIMARY KEY, counts_json TEXT)")
    divisions = [
        "SoCal",
        "NorCal",
        "Mid-Atlantic",
        "Seattle",
        "Mountain West",
        "Southwest",
        "Jewel Osco",
        "Shaws",
        "Southern",
        "Portland",
        "United",
        "Haggen",
    ]
    rows = []
    for i in range(240):
        store = str(1000 + i)
        div = divisions[i % 12]
        om = f"{div} 1"
        rows.append(
            (
                f"R{i}",
                "store_roster",
                store,
                div,
                om,
                f"Store {store}",
                None,
                "{}",
                json.dumps({"district": "01"}),
            )
        )
        loss_div = "Haggen" if haggen_only else div
        loss_om = "" if haggen_only else om
        rows.append(
            (
                f"L{i}",
                "lost_revenue",
                store,
                loss_div,
                loss_om,
                None,
                None,
                json.dumps({"lost_revenue": 10}),
                json.dumps({"lost_grain": "store"}),
            )
        )
    rows.append(
        (
            "G1",
            "dynacap",
            "Applied filters:\nRELATIVE_WEEK is TW",
            "",
            "",
            None,
            None,
            json.dumps({"dynacap_rate": 0}),
            "{}",
        )
    )
    rows.append(
        (
            "D1",
            "dynacap",
            "1704",
            "SoCal",
            "SoCal 03",
            None,
            None,
            json.dumps({"dynacap_rate": 62.4}),
            "{}",
        )
    )
    rows.append(
        (
            "P1",
            "prep_not_ready",
            "1000",
            "SoCal",
            "Mark Bohdanowicz",
            None,
            None,
            json.dumps({"prep_pct": 4.2}),
            "{}",
        )
    )
    for i in range(scorecard_n):
        rows.append(
            (
                f"S{i}",
                "picker_scorecard",
                str(1000 + (i % 240)),
                "",
                "",
                None,
                None,
                json.dumps(
                    {
                        "pph": 70,
                        "orders": 12,
                        "fat_blob": "x" * 200,
                        "presub_pct": 2.1,
                    }
                ),
                json.dumps({"shopper_id": f"SHOP{i:04d}", "unused": "drop"}),
            )
        )
    con.executemany(
        "INSERT INTO facts VALUES (?,?,?,?,?,?,?,?,?)",
        rows,
    )
    con.execute(
        "INSERT INTO dash_chrome VALUES (1, ?)",
        (json.dumps({"pickerShoppers": chrome_shoppers}),),
    )
    con.execute("INSERT INTO pack_meta VALUES (1, '{}')")
    con.commit()
    con.close()


class ThinKeepDropTests(unittest.TestCase):
    def test_orphan_chrome_soft_fails_d4(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "current.sqlite")
            _write_pack(path, scorecard_n=0, haggen_only=True, chrome_shoppers=29249)
            with self.assertRaises(SystemExit) as err:
                thin.thin(path)
            self.assertIn("orphan chrome", str(err.exception))

    def test_keep_slim_scorecard_and_bind_loss(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "current.sqlite")
            _write_pack(path, scorecard_n=1200, haggen_only=True, chrome_shoppers=1200)
            thin.thin(path)
            self.assertLessEqual(os.path.getsize(path), thin.COMPANY_SEAT_MAX)
            con = sqlite3.connect(path)
            score = con.execute(
                "SELECT COUNT(*) FROM facts WHERE section='picker_scorecard'"
            ).fetchone()[0]
            self.assertEqual(score, 1200)
            payload = json.loads(
                con.execute(
                    "SELECT payload_json FROM facts WHERE section='picker_scorecard' LIMIT 1"
                ).fetchone()[0]
            )
            self.assertNotIn("fat_blob", payload)
            self.assertIn("pph", payload)
            divs = {
                d
                for (d,) in con.execute(
                    "SELECT DISTINCT division FROM facts WHERE section='lost_revenue' AND TRIM(store_number)!=''"
                )
            }
            self.assertGreaterEqual(len(divs), 5)
            self.assertIn("United", divs)
            blank = con.execute(
                "SELECT COUNT(*) FROM facts WHERE section='lost_revenue' AND TRIM(COALESCE(operations_om,''))=''"
            ).fetchone()[0]
            self.assertLess(blank * 2, 240)
            garbage = con.execute(
                "SELECT COUNT(*) FROM facts WHERE store_number LIKE 'Applied%'"
            ).fetchone()[0]
            self.assertEqual(garbage, 0)
            item = con.execute(
                "SELECT COUNT(*) FROM facts WHERE section='pre_sub_oos_item'"
            ).fetchone()[0]
            self.assertEqual(item, 0)
            prep_om = con.execute(
                "SELECT operations_om FROM facts WHERE section='prep_not_ready'"
            ).fetchone()[0]
            self.assertEqual(prep_om, "SoCal 1")
            con.close()

    def test_haggen_only_loss_soft_fails_when_roster_cannot_bind(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "current.sqlite")
            _write_pack(path, scorecard_n=1200, haggen_only=True, chrome_shoppers=1200)
            con = sqlite3.connect(path)
            con.execute("UPDATE facts SET store_number='9999' || id WHERE section='lost_revenue'")
            con.commit()
            con.close()
            with self.assertRaises(SystemExit) as err:
                thin.thin(path)
            self.assertIn("Haggen-only", str(err.exception))


if __name__ == "__main__":
    unittest.main()
