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


if __name__ == "__main__":
    unittest.main()
