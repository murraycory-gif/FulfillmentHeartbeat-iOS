#!/usr/bin/env python3
"""Seat publish must fail closed when the cook wrote no store packs."""
from __future__ import annotations

import os
import sqlite3
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUBLISH = ROOT / "Tools" / "HeartbeatIngest" / "publish-cloud.sh"
WORKFLOW = ROOT / ".github" / "workflows" / "cook-heartbeat-pack.yml"
INGEST = ROOT / "Tools" / "HeartbeatIngest" / "Ingest.swift"
PREPARE = ROOT / "Tools" / "HeartbeatIngest" / "prepare-sources.sh"
SEAT_SWIFT = ROOT / "Tools" / "HeartbeatIngest" / "PulseSeatPack.swift"


def write_sqlite(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.execute("CREATE TABLE facts (section TEXT NOT NULL, store_number TEXT NOT NULL)")
    conn.execute("INSERT INTO facts(section, store_number) VALUES ('sales', '12')")
    conn.commit()
    conn.close()


def fake_aws(directory: Path, fail: bool) -> Path:
    path = directory / "aws"
    path.write_text(
        textwrap.dedent(
            """\
            #!/bin/sh
            printf '%s\\n' "$*" >> "${AWS_LOG:?}"
            if [ "${AWS_FAIL:-0}" = "1" ]; then
              exit 1
            fi
            exit 0
            """
        ),
        encoding="utf-8",
    )
    path.chmod(path.stat().st_mode | stat.S_IEXEC)
    return path


def run_seats(sqlite_path: Path, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    merged = os.environ.copy()
    merged.update(env)
    return subprocess.run(
        ["bash", str(PUBLISH), "seats", str(sqlite_path)],
        cwd=ROOT,
        env=merged,
        text=True,
        capture_output=True,
        check=False,
    )


class SeatPublishTests(unittest.TestCase):
    def test_sources_wire_every_store_seat(self) -> None:
        ingest = INGEST.read_text(encoding="utf-8")
        self.assertIn("PulseSeatPack.shouldCookEveryStoreSeat()", ingest)
        self.assertIn("PulseSeatPack.cookPublished(", ingest)
        swift = SEAT_SWIFT.read_text(encoding="utf-8")
        self.assertIn("static func shouldCookEveryStoreSeat() -> Bool { true }", swift)
        self.assertIn("packs/seat/", swift)
        prepare = PREPARE.read_text(encoding="utf-8")
        self.assertIn("PulseSeatPack.swift", prepare)
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertNotIn("continue-on-error", workflow)
        self.assertIn("prepare-sources.sh", workflow)
        self.assertIn("zero store packs", workflow)
        publish = PUBLISH.read_text(encoding="utf-8")
        self.assertNotIn("Skipping seat publish", publish)
        self.assertNotIn("Company LIVE is the pack", publish)

    def test_missing_seat_directory_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            sqlite_path = Path(tmp) / "current.sqlite"
            sqlite_path.write_bytes(b"x")
            result = run_seats(sqlite_path, {})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("COOK FAILED", result.stderr)
        self.assertIn("No packs/seat directory", result.stderr)

    def test_zero_store_packs_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sqlite_path = root / "current.sqlite"
            sqlite_path.write_bytes(b"x")
            (root / "packs" / "seat" / "company" / "all").mkdir(parents=True)
            (root / "packs" / "seat" / "district" / "03").mkdir(parents=True)
            write_sqlite(root / "packs" / "seat" / "district" / "03" / "current.sqlite")
            result = run_seats(sqlite_path, {})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("zero store packs", result.stderr)

    def test_store_pack_upload_succeeds_or_sync_failure_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sqlite_path = root / "current.sqlite"
            write_sqlite(sqlite_path)
            write_sqlite(root / "packs" / "seat" / "store" / "12" / "current.sqlite")
            write_sqlite(root / "packs" / "seat" / "district" / "03" / "current.sqlite")
            log = root / "aws.log"
            fake_aws(root, fail=False)
            env = {
                "PATH": f"{root}:{os.environ.get('PATH', '')}",
                "AWS_LOG": str(log),
                "AWS_FAIL": "0",
                "R2_ACCESS_KEY_ID": "test",
                "R2_SECRET_ACCESS_KEY": "test",
                "R2_ACCOUNT_ID": "test",
                "R2_BUCKET": "heartbeat-packs",
                "SEAT_RESULT_ROOT": str(root / "results"),
            }
            ok = run_seats(sqlite_path, env)
            self.assertEqual(ok.returncode, 0, ok.stderr + ok.stdout)
            logged = log.read_text(encoding="utf-8")
            self.assertIn("s3 sync", logged)
            self.assertIn("packs/seat", logged)

            log.write_text("", encoding="utf-8")
            env["AWS_FAIL"] = "1"
            failed = run_seats(sqlite_path, env)
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn("COOK FAILED", failed.stderr)


if __name__ == "__main__":
    unittest.main()
