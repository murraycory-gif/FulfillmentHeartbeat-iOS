#!/usr/bin/env python3
"""listed_size must not crash on a string or an error payload."""
from __future__ import annotations

import io
import json
import os
import unittest
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from unittest import mock

import pack_freshness as fresh

LIVE_HOST = "https://pub-eafb309f53464d98902d12ac107f0f1e.r2.dev"
ROW = {
    "name": "current.sqlite",
    "metadata": {"size": 32198656, "contentLength": 32198656},
}


class ListedSizeTests(unittest.TestCase):
    def test_list_of_rows(self) -> None:
        self.assertEqual(fresh.listed_size([ROW], "current.sqlite"), 32198656)
        self.assertEqual(fresh.listed_size([ROW], "missing.sqlite"), -1)

    def test_name_map_used_by_cook(self) -> None:
        files = {ROW["name"]: ROW, "Heartbeat Daily Report.xlsx": {"name": "Heartbeat Daily Report.xlsx"}}
        self.assertEqual(fresh.listed_size(files, "current.sqlite"), 32198656)

    def test_string_row_is_missing(self) -> None:
        self.assertEqual(fresh.listed_size(["current.sqlite", "error"], "current.sqlite"), -1)
        self.assertEqual(fresh.listed_size("bucket list failed", "current.sqlite"), -1)

    def test_error_object_is_missing(self) -> None:
        self.assertEqual(
            fresh.listed_size({"message": "Unauthorized", "statusCode": "403"}, "current.sqlite"),
            -1,
        )
        self.assertEqual(fresh.listed_size({"error": "boom"}, "current.sqlite"), -1)

    def test_string_metadata_does_not_crash(self) -> None:
        row = {"name": "current.sqlite", "metadata": "not-json"}
        self.assertEqual(fresh.listed_size([row], "current.sqlite"), 0)
        encoded = {"name": "current.sqlite", "metadata": '{"size": 12}'}
        self.assertEqual(fresh.listed_size([encoded], "current.sqlite"), 12)

    def test_non_numeric_size_is_skipped(self) -> None:
        row = {"name": "current.sqlite", "metadata": {"size": "nope", "contentLength": 9}}
        self.assertEqual(fresh.listed_size([row], "current.sqlite"), 9)


class HeadPackTests(unittest.TestCase):
    def test_sends_non_python_user_agent(self) -> None:
        captured = {}

        class Resp:
            headers = {"Last-Modified": "Wed, 23 Sep 2026 17:49:18 GMT", "Content-Length": "32198656"}

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

        def fake_urlopen(req, timeout=0):
            captured["ua"] = req.get_header("User-agent")
            captured["method"] = req.get_method()
            captured["timeout"] = timeout
            return Resp()

        with mock.patch.object(fresh.urllib.request, "urlopen", fake_urlopen):
            updated, nbytes = fresh.head_pack(LIVE_HOST)
        self.assertEqual(updated, "Wed, 23 Sep 2026 17:49:18 GMT")
        self.assertEqual(nbytes, 32198656)
        self.assertEqual(captured["ua"], fresh.PACK_USER_AGENT)
        self.assertNotIn("Python-urllib", captured["ua"])
        self.assertEqual(captured["method"], "HEAD")

    def test_head_403_then_range_uses_content_range_not_one_byte_length(self) -> None:
        class Resp:
            headers = {
                "Last-Modified": "Wed, 23 Sep 2026 17:49:18 GMT",
                "Content-Range": "bytes 0-0/32198656",
                "Content-Length": "1",
            }

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

        def fake_urlopen(req, timeout=0):
            if req.get_method() == "HEAD":
                raise urllib.error.HTTPError(req.full_url, 403, "Forbidden", hdrs=None, fp=io.BytesIO(b""))
            self.assertEqual(req.get_header("Range"), "bytes=0-0")
            return Resp()

        with mock.patch.object(fresh.urllib.request, "urlopen", fake_urlopen):
            updated, nbytes = fresh.head_pack(LIVE_HOST)
        self.assertEqual(updated, "Wed, 23 Sep 2026 17:49:18 GMT")
        self.assertEqual(nbytes, 32198656)

    def test_head_and_range_403_uses_s3api(self) -> None:
        def fake_urlopen(req, timeout=0):
            raise urllib.error.HTTPError(req.full_url, 403, "Forbidden", hdrs=None, fp=io.BytesIO(b""))

        payload = json.dumps(
            {"ContentLength": 32198656, "LastModified": "2026-09-23T17:49:18+00:00"}
        )

        class Proc:
            returncode = 0
            stdout = payload
            stderr = ""

        env = {name: "set" for name in fresh.R2_SECRET_NAMES}
        with mock.patch.dict(os.environ, env, clear=False):
            with mock.patch.object(fresh.urllib.request, "urlopen", fake_urlopen):
                with mock.patch.object(fresh.shutil, "which", return_value="/usr/bin/aws"):
                    with mock.patch.object(fresh.subprocess, "run", return_value=Proc()) as run:
                        updated, nbytes = fresh.head_pack(LIVE_HOST)
        self.assertEqual(updated, "2026-09-23T17:49:18+00:00")
        self.assertEqual(nbytes, 32198656)
        cmd = run.call_args.args[0]
        self.assertEqual(cmd[:3], ["aws", "s3api", "head-object"])
        self.assertIn("current.sqlite", cmd)

    def test_head_failure_is_missing_not_raised_and_does_not_skip(self) -> None:
        def fake_urlopen(req, timeout=0):
            raise urllib.error.HTTPError(req.full_url, 403, "Forbidden", hdrs=None, fp=io.BytesIO(b""))

        cleared = {name: "" for name in fresh.R2_SECRET_NAMES}
        with mock.patch.dict(os.environ, cleared, clear=False):
            with mock.patch.object(fresh.urllib.request, "urlopen", fake_urlopen):
                with mock.patch("sys.stdout", new=io.StringIO()) as out:
                    updated, nbytes = fresh.head_pack(LIVE_HOST)
        self.assertEqual((updated, nbytes), ("", 0))
        text = out.getvalue()
        self.assertIn("403", text)
        self.assertIn("Not skipping", text)
        self.assertIn("Cook continues", text)
        self.assertFalse(
            fresh.should_skip_cook(False, datetime(2026, 9, 23, tzinfo=timezone.utc), datetime(2026, 9, 23, tzinfo=timezone.utc), nbytes)
        )

    def test_live_python_urllib_is_403_and_cook_agent_is_200(self) -> None:
        url = f"{LIVE_HOST}/current.sqlite"
        blocked = urllib.request.Request(url, method="HEAD")
        try:
            urllib.request.urlopen(blocked, timeout=20)
            self.fail("default Python-urllib HEAD should be 403 on r2.dev")
        except urllib.error.HTTPError as exc:
            self.assertEqual(exc.code, 403)
        updated, nbytes = fresh.head_pack(LIVE_HOST)
        self.assertTrue(updated)
        self.assertGreaterEqual(nbytes, 1_000_000)
        self.assertLessEqual(nbytes, 40_000_000)


class SkipCookTests(unittest.TestCase):
    def test_failed_head_does_not_skip_and_dispatch_still_cooks(self) -> None:
        older = datetime(2026, 9, 23, 15, 6, tzinfo=timezone.utc)
        pack = datetime(2026, 9, 23, 17, 49, tzinfo=timezone.utc)
        self.assertFalse(fresh.should_skip_cook(False, older, None, 0))
        self.assertFalse(fresh.should_skip_cook(False, older, pack, 0))
        self.assertFalse(fresh.should_skip_cook(True, older, pack, 32198656))
        self.assertTrue(fresh.should_skip_cook(False, older, pack, 32198656))
        self.assertFalse(fresh.should_skip_cook(False, pack, older, 32198656))

    def test_workflow_passes_row_values_not_dict_keys(self) -> None:
        text = Path(__file__).resolve().parents[2].joinpath(".github/workflows/cook-heartbeat-pack.yml").read_text()
        self.assertIn('listed_size(list(files.values()), "current.sqlite")', text)
        self.assertNotIn("listed_size(files,", text)


if __name__ == "__main__":
    unittest.main()
