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
        store = str(1000 + (i % 240))
        ldap = f"SHOP{i:04d}"
        rows.append(
            (
                f"S{i}",
                "picker_scorecard",
                store,
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
                        **({"coe_pct": 18.4} if i % 2 == 0 else {}),
                    }
                ),
                json.dumps({"shopper_id": ldap, "unused": "drop"}),
            )
        )
        rows.append(
            (
                f"K{i}",
                "pick_path_picker",
                "",
                "",
                "",
                None,
                None,
                json.dumps({"compliance_pct": 76.5, "orders": 10, "fat_path": "y" * 80}),
                json.dumps({"shopper_id": ldap, "shopper_name": ldap}),
            )
        )
    # Excel hole: Path LDAP with no ScoreCard store grain — do not invent.
    rows.append(
        (
            "KHOLE",
            "pick_path_picker",
            "",
            "",
            "",
            None,
            None,
            json.dumps({"compliance_pct": 61.0, "orders": 4}),
            json.dumps({"shopper_id": "NOGRAIN1", "shopper_name": "NOGRAIN1"}),
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
            with_coe = json.loads(
                con.execute(
                    "SELECT payload_json FROM facts WHERE section='picker_scorecard' AND id='S0'"
                ).fetchone()[0]
            )
            self.assertEqual(with_coe.get("coe_pct"), 18.4)
            without_coe = json.loads(
                con.execute(
                    "SELECT payload_json FROM facts WHERE section='picker_scorecard' AND id='S1'"
                ).fetchone()[0]
            )
            self.assertNotIn("coe_pct", without_coe)
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
            path_n = con.execute(
                "SELECT COUNT(*) FROM facts WHERE section='pick_path_picker'"
            ).fetchone()[0]
            self.assertEqual(path_n, 1201)
            bound = con.execute(
                "SELECT store_number, division, operations_om FROM facts "
                "WHERE section='pick_path_picker' AND json_extract(text_json,'$.shopper_id')='SHOP0000'"
            ).fetchone()
            self.assertEqual(bound[0], "1000")
            self.assertEqual(bound[1], "SoCal")
            self.assertEqual(bound[2], "SoCal 1")
            hole = con.execute(
                "SELECT store_number FROM facts "
                "WHERE section='pick_path_picker' AND json_extract(text_json,'$.shopper_id')='NOGRAIN1'"
            ).fetchone()[0]
            self.assertEqual((hole or "").strip(), "")
            score_text = json.loads(
                con.execute(
                    "SELECT text_json FROM facts WHERE section='picker_scorecard' AND id='S0'"
                ).fetchone()[0]
            )
            self.assertEqual(score_text.get("shopper_id"), "SHOP0000")
            self.assertNotIn("shopper_name", score_text)
            self.assertNotIn("district", score_text)
            self.assertNotIn("data_window", score_text)
            blank_bindable = con.execute(
                """
                SELECT COUNT(*) FROM facts
                WHERE section='pick_path_picker'
                  AND TRIM(COALESCE(store_number,''))=''
                  AND json_extract(text_json,'$.shopper_id') IN (
                      SELECT json_extract(text_json,'$.shopper_id')
                      FROM facts
                      WHERE section='picker_scorecard' AND TRIM(store_number)!=''
                  )
                """
            ).fetchone()[0]
            self.assertEqual(blank_bindable, 0)
            con.close()

    def test_path_picker_empty_store_soft_fails_when_ldap_grain_exists(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "current.sqlite")
            _write_pack(path, scorecard_n=1200, haggen_only=False, chrome_shoppers=1200)
            con = sqlite3.connect(path)
            stores_by_ldap = thin.scorecard_store_by_ldap(con)
            self.assertIn("SHOP0000", stores_by_ldap)
            with self.assertRaises(SystemExit) as err:
                thin.refuse_path_store_bind(con, stores_by_ldap)
            self.assertIn("pick_path_picker store_number empty", str(err.exception))
            self.assertIn("ScoreCard store grain", str(err.exception))
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


TODAY_SCORE = 27349
TODAY_PATH = 27023
DIVISIONS = (
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
)


def _schema(con: sqlite3.Connection) -> None:
    con.execute(
        """CREATE TABLE facts (
            id TEXT PRIMARY KEY, section TEXT NOT NULL, store_number TEXT NOT NULL,
            division TEXT, operations_om TEXT, store_name TEXT, recorded_on TEXT,
            payload_json TEXT, text_json TEXT
        )"""
    )
    con.execute("CREATE TABLE dash_chrome (id INTEGER PRIMARY KEY, json TEXT NOT NULL)")
    con.execute("CREATE TABLE pack_meta (id INTEGER PRIMARY KEY, counts_json TEXT)")


def _write_today_pack(path: str) -> None:
    """Row counts from the 2026-09-25 cook (scorecard 27349, path 27023), fat enough to start over 40MB."""
    con = sqlite3.connect(path)
    _schema(con)
    rows = []
    for i in range(2161):
        store = str(1000 + i)
        div = DIVISIONS[i % len(DIVISIONS)]
        rows.append(
            (
                f"R{i}",
                "store_roster",
                store,
                div,
                f"{div} 1",
                f"Store {store}",
                None,
                "{}",
                json.dumps({"district": f"D{i % 40}"}),
            )
        )
        rows.append(
            (
                f"L{i}",
                "lost_revenue",
                store,
                div,
                f"{div} 1",
                None,
                None,
                json.dumps({"lost_revenue": 10}),
                "{}",
            )
        )
    fat = "x" * 900
    path_fat = "y" * 700
    for i in range(TODAY_SCORE):
        store = str(1000 + (i % 2161))
        ldap = f"SHOP{i:05d}"
        name = "Jane Shopper" if i == 3 else ldap
        rows.append(
            (
                f"S{i}",
                "picker_scorecard",
                store,
                "",
                "",
                None,
                None,
                json.dumps(
                    {
                        "pph": 41.637888505180065,
                        "orders": 12,
                        "presub_pct": 2.1,
                        "qty_ordered": 40,
                        "dug_orders": 3,
                        "refund_amt": 1.5,
                        "fat_blob": fat,
                    }
                ),
                json.dumps(
                    {
                        "shopper_id": ldap,
                        "shopper_name": name,
                        "district": "D1",
                        "data_window": "Aug 30 – Aug 31, 2026",
                        "qty_ordered": "40",
                    }
                ),
            )
        )
    for i in range(TODAY_PATH):
        ldap = f"SHOP{i:05d}"
        rows.append(
            (
                f"K{i}",
                "pick_path_picker",
                "",
                "",
                "",
                None,
                None,
                json.dumps(
                    {
                        "compliance_pct": 76.54321098765432,
                        "orders": 10,
                        "pph": 41.63,
                        "fat_path": path_fat,
                    }
                ),
                json.dumps({"shopper_id": ldap, "shopper_name": ldap, "district": "D1"}),
            )
        )
    # Other grains at the live pack's average JSON sizes (2026-09-25 current.sqlite).
    # These are not slimmed; they are why a path-keeping seat sits near 40MB.
    other = (
        ("sales", 2179, 2660, 133),
        ("missing_items", 2164, 460, 17),
        ("pre_sub_oos", 2164, 395, 78),
        ("labor", 1716, 475, 56),
        ("schedule_quality", 2084, 362, 53),
        ("five_star", 2162, 237, 74),
        ("pick_path", 2143, 129, 60),
        ("dynacap", 2164, 160, 17),
        ("pph", 2321, 34, 80),
        ("aisle_mapper", 2151, 2, 85),
        ("prep_not_ready", 1298, 35, 60),
    )
    for section, count, payload_n, text_n in other:
        payload = json.dumps({"blob": "p" * payload_n})
        text = json.dumps({"blob": "t" * text_n})
        for i in range(count):
            store = str(1000 + (i % 2161))
            div = DIVISIONS[i % len(DIVISIONS)]
            rows.append(
                (
                    f"{section}-{i}",
                    section,
                    store,
                    div,
                    f"{div} 1",
                    None,
                    None,
                    payload,
                    text,
                )
            )
    for i in range(12000):
        rows.append(
            (
                f"I{i}",
                "pre_sub_oos_item",
                str(1000 + (i % 2161)),
                "SoCal",
                "SoCal 1",
                None,
                None,
                json.dumps({"item": "z" * 400}),
                "{}",
            )
        )
    con.executemany("INSERT INTO facts VALUES (?,?,?,?,?,?,?,?,?)", rows)
    con.execute(
        "INSERT INTO dash_chrome VALUES (1, ?)",
        (json.dumps({"pickerShoppers": TODAY_SCORE}),),
    )
    con.execute("INSERT INTO pack_meta VALUES (1, '{}')")
    con.commit()
    con.close()


class PathKeeperTests(unittest.TestCase):
    def test_today_sized_pack_keeps_path_under_cap(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "current.sqlite")
            _write_today_pack(path)
            before = os.path.getsize(path)
            self.assertGreater(before, thin.COMPANY_SEAT_MAX)
            thin.thin(path)
            after = os.path.getsize(path)
            print(f"today_fixture before_bytes={before} thin_bytes={after}")
            self.assertLessEqual(after, thin.COMPANY_SEAT_MAX)
            con = sqlite3.connect(path)
            path_n = con.execute(
                "SELECT COUNT(*) FROM facts WHERE section='pick_path_picker'"
            ).fetchone()[0]
            self.assertEqual(path_n, TODAY_PATH)
            dup = json.loads(
                con.execute(
                    "SELECT text_json FROM facts WHERE section='picker_scorecard' AND id='S0'"
                ).fetchone()[0]
            )
            self.assertEqual(dup.get("shopper_id"), "SHOP00000")
            self.assertNotIn("shopper_name", dup)
            self.assertNotIn("district", dup)
            self.assertNotIn("data_window", dup)
            named = json.loads(
                con.execute(
                    "SELECT text_json FROM facts WHERE section='picker_scorecard' AND id='S3'"
                ).fetchone()[0]
            )
            self.assertEqual(named.get("shopper_name"), "Jane Shopper")
            payload = json.loads(
                con.execute(
                    "SELECT payload_json FROM facts WHERE section='picker_scorecard' AND id='S0'"
                ).fetchone()[0]
            )
            self.assertNotIn("qty_ordered", payload)
            self.assertNotIn("dug_orders", payload)
            self.assertNotIn("refund_amt", payload)
            self.assertNotIn("fat_blob", payload)
            self.assertIn("pph", payload)
            path_text = json.loads(
                con.execute(
                    "SELECT text_json FROM facts WHERE section='pick_path_picker' AND id='K0'"
                ).fetchone()[0]
            )
            self.assertNotIn("shopper_name", path_text)
            self.assertEqual(path_text.get("shopper_id"), "SHOP00000")
            con.close()

    def test_over_cap_fails_and_keeps_path_rows(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "current.sqlite")
            _write_pack(path, scorecard_n=1200, haggen_only=False, chrome_shoppers=1200)
            original = thin.COMPANY_SEAT_MAX
            thin.COMPANY_SEAT_MAX = 1
            try:
                with self.assertRaises(SystemExit) as err:
                    thin.thin(path)
            finally:
                thin.COMPANY_SEAT_MAX = original
            self.assertIn("too large", str(err.exception))
            con = sqlite3.connect(path)
            path_n = con.execute(
                "SELECT COUNT(*) FROM facts WHERE section='pick_path_picker'"
            ).fetchone()[0]
            con.close()
            self.assertGreater(path_n, 0)

    def test_guard_fails_when_thinned_path_is_zero(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "current.sqlite")
            _write_pack(path, scorecard_n=1200, haggen_only=False, chrome_shoppers=1200)
            con = sqlite3.connect(path)
            con.execute("DELETE FROM facts WHERE section='pick_path_picker'")
            con.commit()
            with self.assertRaises(SystemExit) as err:
                thin.refuse_thinned_path(con, 1201)
            self.assertIn("thinned pack has 0", str(err.exception))
            con.close()

    def test_guard_fails_when_division_gap_exceeds_five_percent(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "current.sqlite")
            con = sqlite3.connect(path)
            _schema(con)
            rows = []
            for i, div in enumerate(DIVISIONS):
                rows.append(
                    ("S" + div, "picker_scorecard", "1000", div, "", None, None, "{}", "{}")
                )
                if i < 10:
                    rows.append(
                        ("K" + div, "pick_path_picker", "1000", div, "", None, None, "{}", "{}")
                    )
            con.executemany("INSERT INTO facts VALUES (?,?,?,?,?,?,?,?,?)", rows)
            con.commit()
            with self.assertRaises(SystemExit) as err:
                thin.refuse_thinned_path(con, 10)
            self.assertIn("scorecard divisions have no pick_path_picker", str(err.exception))
            con.execute("DELETE FROM facts")
            # Exactly 5% missing (1 of 20) is allowed.
            keep = []
            for i in range(20):
                div = f"D{i}"
                keep.append(("S" + div, "picker_scorecard", "1", div, "", None, None, "{}", "{}"))
                if i > 0:
                    keep.append(("K" + div, "pick_path_picker", "1", div, "", None, None, "{}", "{}"))
            con.executemany("INSERT INTO facts VALUES (?,?,?,?,?,?,?,?,?)", keep)
            con.commit()
            thin.refuse_thinned_path(con, 19)
            con.close()


if __name__ == "__main__":
    unittest.main()
