#!/usr/bin/env python3
"""Cross-check the schedule cook against Cory's Week 32 first-look workbook.

The xlsx is not in git. Set SCHEDULE_XLSX, or place the file at the upload
path used in development. When the file is absent the test skips so CI does
not fail closed on a private workbook.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import cook_schedule as cook


class QualifyTests(unittest.TestCase):
    def test_gate(self):
        self.assertFalse(cook.qualifies(None, 20, 20, 20))
        self.assertFalse(cook.qualifies(29999.99, 20, 20, 20))
        self.assertTrue(cook.qualifies(30000, 10, 0, 0))
        self.assertFalse(cook.qualifies(30000, 9.99, 9, 14.99))
        self.assertFalse(cook.qualifies(30000, 0, 9, 0))
        self.assertTrue(cook.qualifies(30000, 0, 9.01, 0))
        self.assertTrue(cook.qualifies(30000, 0, 0, 15))
        self.assertFalse(cook.qualifies(30000, None, None, None))


class WorkbookCrossCheckTests(unittest.TestCase):
    def test_week32_summary_math(self):
        path = os.environ.get("SCHEDULE_XLSX") or "/home/ubuntu/.cursor/projects/workspace/uploads/sched_e2a3.xlsx"
        if not path or not os.path.isfile(path):
            self.skipTest("Schedule Review workbook is not on this machine")
        pack = cook.cook_workbook(path)
        report = pack["crossCheck"]
        self.assertEqual(report["week"], 32)
        self.assertEqual(report["scope"], 2163)
        self.assertEqual(report["underCount"], 2008)
        self.assertEqual(report["overCount"], 1566)
        self.assertEqual(cook.round2(report["eff"]), 64.97)
        self.assertEqual(cook.round2(report["pch"]), 70.28)
        self.assertEqual(cook.round2(report["marketUnder"]), 41.07)
        self.assertEqual(cook.round2(report["marketOver"]), 4.03)
        self.assertEqual(cook.round2(report["storeUnder"]), 23.14)
        self.assertEqual(cook.round2(report["storeOver"]), 13.08)
        self.assertNotEqual(cook.round2(report["storeUnder"]), 41.07)
        self.assertEqual(report["actionCount"], 472)
        self.assertEqual(report["bannerCount"], 468)
        self.assertNotEqual(report["actionCount"], report["bannerCount"])
        self.assertEqual(
            report["regions"],
            {
                "East Region": 612,
                "South Region": 397,
                "California Region": 600,
                "West Region": 554,
            },
        )
        self.assertIn("Week 31", report["summaryTitle"])
        self.assertNotIn("Week 32", report["summaryTitle"])
        shaws = next(item for item in pack["markets"] if item["label"] == "Shaws")
        self.assertEqual(cook.round2(shaws["under"]), 87.99)
        united = next(item for item in pack["markets"] if item["label"] == "United")
        self.assertIsNone(united["under"])
        self.assertIsNone(united["over"])
        store117 = next(item for item in pack["stores"] if item["store"] == "117")
        self.assertEqual(store117["division"], "Shaws")
        self.assertEqual(store117["region"], "East Region")
        self.assertAlmostEqual(store117["sales"], 33961.9775, places=2)
        self.assertGreaterEqual(store117["under"], 99.5)
        self.assertAlmostEqual(store117["eff"], 0.0, places=4)


class CookArgsTests(unittest.TestCase):
    def sample_report(self, **overrides):
        report = {
            "scope": 2163,
            "underCount": 2008,
            "overCount": 1566,
            "eff": 64.97,
            "pch": 70.28,
            "marketUnder": 41.07,
            "marketOver": 4.03,
            "storeUnder": 23.14,
            "storeOver": 13.08,
            "actionCount": 472,
            "bannerCount": 468,
            "notScheduled": 12,
            "regions": {},
            "summaryTitle": "Schedule Review Summary — Week 31",
            "week": 32,
        }
        report.update(overrides)
        return report

    def test_find_positional_is_the_output_path(self):
        args = cook.parse_args(["--find", "/tmp/Heartbeat_Reports", "/tmp/schedule-check.json"])
        self.assertIsNone(args.workbook)
        self.assertEqual(args.output, "/tmp/schedule-check.json")
        self.assertEqual(args.find, "/tmp/Heartbeat_Reports")

    def test_workbook_then_output_stays_positional(self):
        args = cook.parse_args(["/tmp/book.xlsx", "/tmp/schedule-check.json", "--check"])
        self.assertEqual(args.workbook, "/tmp/book.xlsx")
        self.assertEqual(args.output, "/tmp/schedule-check.json")
        self.assertTrue(args.check)

    def test_informational_notes_do_not_fail_company_numbers(self):
        report = self.sample_report()
        self.assertTrue(cook.company_numbers_ok(report))
        self.assertTrue(cook.print_cross_check(report))

    def test_company_number_miss_fails(self):
        report = self.sample_report(scope=1)
        self.assertFalse(cook.company_numbers_ok(report))
        self.assertFalse(cook.print_cross_check(report))

    def test_sqlite_rows_land_in_current_sqlite(self):
        import sqlite3
        import tempfile

        with tempfile.TemporaryDirectory() as folder:
            dest = os.path.join(folder, "current.sqlite")
            connection = sqlite3.connect(dest)
            connection.execute("CREATE TABLE facts (id TEXT PRIMARY KEY)")
            connection.execute("INSERT INTO facts(id) VALUES ('keep-me')")
            connection.commit()
            connection.close()
            pack = {
                "publishedAt": "2026-09-28T12:00:00Z",
                "week": 32,
                "filename": "Schedule Review Week 32.xlsx",
                "summaryTitle": "Summary",
                "workbookActionBanner": 468,
                "markets": [{"label": "Total", "under": 41.07, "over": 4.03, "eff": 64.97}],
                "stores": [{
                    "store": "117",
                    "region": "East Region",
                    "division": "Shaws",
                    "district": "B5",
                    "om": "Pat",
                    "sales": 33961.98,
                    "under": 100.0,
                    "over": 0.0,
                    "eff": 0.0,
                    "pch": None,
                    "fourUnder": 9.2,
                    "fourOver": None,
                    "star": None,
                    "dayUnder": [1, None, None, None, None, None, None],
                    "dayOver": [None] * 7,
                }],
                "crossCheck": self.sample_report(),
            }
            original = cook.cook_workbook
            cook.cook_workbook = lambda path: pack
            try:
                code = cook.main(["/tmp/unused.xlsx", "--sqlite", dest])
            finally:
                cook.cook_workbook = original
            self.assertEqual(code, 0)
            connection = sqlite3.connect(dest)
            self.assertEqual(connection.execute("SELECT id FROM facts").fetchone()[0], "keep-me")
            row = connection.execute(
                "SELECT week, filename, workbook_action_banner FROM schedule_pack WHERE id = 1"
            ).fetchone()
            self.assertEqual(row, (32, "Schedule Review Week 32.xlsx", 468))
            market = connection.execute("SELECT label, under FROM schedule_market").fetchone()
            self.assertEqual(market[0], "Total")
            self.assertAlmostEqual(market[1], 41.07, places=2)
            store = connection.execute(
                "SELECT store, division, under, day_under_json FROM schedule_store"
            ).fetchone()
            self.assertEqual(store[0], "117")
            self.assertEqual(store[1], "Shaws")
            self.assertAlmostEqual(store[2], 100.0, places=2)
            self.assertIn("1", store[3])
            connection.close()

    def test_publish_sheet_writes_workbook_rows_when_lock_misses(self):
        import sqlite3
        import tempfile

        with tempfile.TemporaryDirectory() as folder:
            dest = os.path.join(folder, "current.sqlite")
            sqlite3.connect(dest).close()
            pack = {
                "publishedAt": "2026-10-05T00:00:00Z",
                "week": 32,
                "filename": "Schedule Review Week 32 - Summary.xlsx",
                "summaryTitle": "Schedule Review Summary — Week 31 (WK31)",
                "workbookActionBanner": 468,
                "markets": [{"label": "Total", "under": 5.01, "over": 6.55, "eff": 64.97}],
                "stores": [{
                    "store": "117",
                    "region": "East Region",
                    "division": "Shaws",
                    "district": "B5",
                    "om": "Pat",
                    "sales": 33961.98,
                    "under": 5.01,
                    "over": 6.55,
                    "eff": 64.97,
                    "pch": 70.67,
                    "fourUnder": None,
                    "fourOver": None,
                    "star": None,
                    "dayUnder": [None] * 7,
                    "dayOver": [None] * 7,
                }],
                "crossCheck": self.sample_report(marketUnder=5.01, marketOver=6.55, pch=70.67),
            }
            original = cook.cook_workbook
            cook.cook_workbook = lambda path: pack
            try:
                code = cook.main(["/tmp/unused.xlsx", "--sqlite", dest, "--publish-sheet"])
            finally:
                cook.cook_workbook = original
            self.assertEqual(code, 0)
            connection = sqlite3.connect(dest)
            market = connection.execute("SELECT under, over FROM schedule_market WHERE label = 'Total'").fetchone()
            self.assertAlmostEqual(market[0], 5.01, places=2)
            self.assertAlmostEqual(market[1], 6.55, places=2)
            self.assertNotAlmostEqual(market[0], 41.07, places=2)
            connection.close()

    def test_publish_sheet_refuses_empty_store_list(self):
        import sqlite3
        import tempfile

        with tempfile.TemporaryDirectory() as folder:
            dest = os.path.join(folder, "current.sqlite")
            sqlite3.connect(dest).close()
            pack = {"week": 32, "stores": [], "crossCheck": self.sample_report(scope=1)}
            original = cook.cook_workbook
            cook.cook_workbook = lambda path: pack
            try:
                code = cook.main(["/tmp/unused.xlsx", "--sqlite", dest, "--publish-sheet"])
            finally:
                cook.cook_workbook = original
            self.assertEqual(code, 1)
            connection = sqlite3.connect(dest)
            tables = {
                row[0]
                for row in connection.execute("SELECT name FROM sqlite_master WHERE type = 'table'")
            }
            self.assertNotIn("schedule_store", tables)
            connection.close()

    def test_company_miss_does_not_write_sqlite(self):
        import sqlite3
        import tempfile

        with tempfile.TemporaryDirectory() as folder:
            dest = os.path.join(folder, "current.sqlite")
            sqlite3.connect(dest).close()
            pack = {"week": 32, "stores": [], "crossCheck": self.sample_report(scope=1)}
            original = cook.cook_workbook
            cook.cook_workbook = lambda path: pack
            try:
                code = cook.main(["/tmp/unused.xlsx", "--sqlite", dest])
            finally:
                cook.cook_workbook = original
            self.assertEqual(code, 1)
            connection = sqlite3.connect(dest)
            tables = {
                row[0]
                for row in connection.execute("SELECT name FROM sqlite_master WHERE type = 'table'")
            }
            self.assertNotIn("schedule_store", tables)
            connection.close()

    def test_matching_numbers_write_json(self):
        import tempfile

        with tempfile.TemporaryDirectory() as folder:
            out = os.path.join(folder, "schedule-check.json")
            pack = {"week": 32, "stores": [], "crossCheck": self.sample_report()}
            original = cook.cook_workbook
            cook.cook_workbook = lambda path: pack
            try:
                code = cook.main(["/tmp/unused.xlsx", out])
            finally:
                cook.cook_workbook = original
            self.assertEqual(code, 0)
            self.assertTrue(os.path.isfile(out))

    def test_company_miss_removes_json_and_exits_nonzero(self):
        import tempfile

        with tempfile.TemporaryDirectory() as folder:
            out = os.path.join(folder, "schedule-check.json")
            pack = {"week": 32, "stores": [], "crossCheck": self.sample_report(scope=1)}
            original = cook.cook_workbook
            cook.cook_workbook = lambda path: pack
            try:
                code = cook.main(["/tmp/unused.xlsx", out])
            finally:
                cook.cook_workbook = original
            self.assertEqual(code, 1)
            self.assertFalse(os.path.isfile(out))

    def test_find_with_no_workbook_exits_nonzero(self):
        import tempfile

        with tempfile.TemporaryDirectory() as folder:
            out = os.path.join(folder, "schedule-check.json")
            code = cook.main(["--find", folder, out])
            self.assertEqual(code, 1)
            self.assertFalse(os.path.isfile(out))

    def test_missing_path_exits_nonzero(self):
        code = cook.main([])
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
