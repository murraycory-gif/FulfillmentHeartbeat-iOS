#!/usr/bin/env python3
"""Company manifest bytes must match the sqlite file that will be published."""
from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path

import write_manifest


def write_sqlite(path: Path, rows: list[tuple[str, str]]) -> None:
    conn = sqlite3.connect(path)
    conn.execute(
        "CREATE TABLE facts (section TEXT NOT NULL, store_number TEXT NOT NULL)"
    )
    conn.executemany("INSERT INTO facts(section, store_number) VALUES (?, ?)", rows)
    conn.commit()
    conn.close()


class WriteManifestTests(unittest.TestCase):
    def test_company_bytes_match_file_and_seats_come_from_disk(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            company = root / "current.sqlite"
            write_sqlite(
                company,
                [("sales", "1"), ("sales", "1"), ("labor", "2")],
            )
            district = root / "packs" / "seat" / "district" / "03" / "current.sqlite"
            district.parent.mkdir(parents=True)
            write_sqlite(district, [("sales", "9")])
            manifest = write_manifest.build_manifest(
                company,
                root / "packs",
                "HB-0828.315",
                "2026-09-25T12:00:00Z",
            )
            self.assertEqual(manifest["company"]["bytes"], company.stat().st_size)
            self.assertNotEqual(manifest["company"]["bytes"], 14_241_792)
            self.assertEqual(manifest["company"]["sectionStoreCounts"]["sales"], 2)
            self.assertEqual(manifest["company"]["sectionStoreCounts"]["labor"], 1)
            self.assertEqual(manifest["company"]["storeCount"], 2)
            self.assertEqual(manifest["stamp"], "HB-0828.315")
            self.assertEqual(manifest["cookedAt"], "2026-09-25T12:00:00Z")
            self.assertEqual(len(manifest["districts"]), 1)
            self.assertEqual(manifest["districts"][0]["id"], "03")
            self.assertEqual(manifest["districts"][0]["bytes"], district.stat().st_size)
            self.assertEqual(manifest["oms"], [])
            self.assertEqual(manifest["stores"], [])

    def test_stamp_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "BuildStamp.swift"
            path.write_text('enum BuildStamp { static let id = "HB-0828.315" }\n', encoding="utf-8")
            self.assertEqual(write_manifest.stamp_from_swift(path), "HB-0828.315")


if __name__ == "__main__":
    unittest.main()
