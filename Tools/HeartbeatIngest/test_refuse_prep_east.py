#!/usr/bin/env python3
"""Gate: Prep Hours % must not publish as 100, and East Dynacap is not invented."""
from __future__ import annotations

import json
import sqlite3
import unittest

import refuse_prep_east as gate


def _pack() -> sqlite3.Connection:
    con = sqlite3.connect(":memory:")
    con.execute(
        """CREATE TABLE facts (
            id TEXT PRIMARY KEY, section TEXT NOT NULL, store_number TEXT NOT NULL,
            division TEXT, operations_om TEXT, store_name TEXT, recorded_on TEXT,
            payload_json TEXT, text_json TEXT
        )"""
    )
    return con


def _add(con: sqlite3.Connection, section: str, store: str, division: str, payload: dict | None = None) -> None:
    row_id = f"{section}-{store}-{division}-{con.execute('SELECT COUNT(*) FROM facts').fetchone()[0]}"
    con.execute(
        "INSERT INTO facts(id, section, store_number, division, payload_json, text_json) VALUES (?,?,?,?,?,?)",
        (row_id, section, store, division, json.dumps(payload or {}), "{}"),
    )


class RefusePrepEastTests(unittest.TestCase):
    def test_fractional_prep_and_east_dynacap_pass(self) -> None:
        con = _pack()
        _add(con, "prep_not_ready", "1432", "Southern", {"pnr_rate_pct": 8.275})
        _add(con, "prep_not_ready", "3427", "Haggen", {"pnr_rate_pct": 0})
        _add(con, "store_roster", "1432", "Jewel Osco")
        _add(con, "store_roster", "52", "Mid-Atlantic")
        _add(con, "store_roster", "88", "Shaws")
        _add(con, "dynacap", "01432", "", {"dynacap_rate": 70})
        _add(con, "dynacap", "52", "Mid Atlantic", {"dynacap_rate": 61})
        _add(con, "dynacap", "88", "Shaws", {"dynacap_rate": 66})
        report, failures = gate.evaluate(con)
        self.assertEqual(failures, [])
        self.assertTrue(any(line.startswith("prep_not_ready n=2 mean=4.1375") for line in report))
        self.assertTrue(any("dynacap_east Jewel Osco=1 Mid-Atlantic=1 Shaws=1 total=3" in line for line in report))

    def test_store_hash_hundreds_refuse(self) -> None:
        con = _pack()
        for index in range(50):
            _add(con, "prep_not_ready", str(1000 + index), "United", {"pnr_rate_pct": 100})
        for index in range(3):
            _add(con, "prep_not_ready", str(2000 + index), "United", {"pnr_rate_pct": 3.8})
        _add(con, "store_roster", "1", "United")
        _add(con, "dynacap", "1", "United", {"dynacap_rate": 70})
        _, failures = gate.evaluate(con)
        self.assertTrue(any("mean" in line and "> 20" in line for line in failures))
        self.assertTrue(any("== 100" in line for line in failures))
        self.assertFalse(any("East hole" in line for line in failures))

    def test_east_hole_refuses_and_does_not_require_invented_rows(self) -> None:
        con = _pack()
        _add(con, "prep_not_ready", "1432", "Southern", {"pnr_rate_pct": 3.01})
        for division, store in (("Jewel Osco", "10"), ("Mid-Atlantic", "20"), ("Shaws", "30"), ("SoCal", "40")):
            _add(con, "store_roster", store, division)
        _add(con, "dynacap", "40", "SoCal", {"dynacap_rate": 72})
        _add(con, "dynacap", "41", "Portland", {"dynacap_rate": 68})
        report, failures = gate.evaluate(con)
        self.assertTrue(any("roster_east" in line and "total=3" in line for line in report))
        self.assertTrue(any("dynacap_east" in line and "total=0" in line for line in report))
        self.assertEqual(len(failures), 1)
        self.assertIn("East hole", failures[0])
        self.assertIn("Not inventing East rows", failures[0])
        dynacap_n = con.execute("SELECT COUNT(*) FROM facts WHERE section='dynacap'").fetchone()[0]
        self.assertEqual(dynacap_n, 2)

    def test_roster_without_east_does_not_refuse(self) -> None:
        con = _pack()
        _add(con, "prep_not_ready", "3427", "Haggen", {"pnr_rate_pct": 1.7})
        _add(con, "store_roster", "3427", "Haggen")
        _add(con, "dynacap", "3427", "Haggen", {"dynacap_rate": 80})
        _, failures = gate.evaluate(con)
        self.assertEqual(failures, [])

    def test_mean_at_20_does_not_refuse(self) -> None:
        con = _pack()
        _add(con, "prep_not_ready", "1", "United", {"pnr_rate_pct": 20})
        _add(con, "prep_not_ready", "2", "United", {"pnr_rate_pct": 20})
        _add(con, "store_roster", "1", "United")
        _add(con, "dynacap", "1", "United", {"dynacap_rate": 70})
        _, failures = gate.evaluate(con)
        self.assertEqual(failures, [])


if __name__ == "__main__":
    unittest.main()
