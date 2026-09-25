#!/usr/bin/env python3
"""listed_size must not crash on a string or an error payload."""
from __future__ import annotations

import io
import unittest
import urllib.error
import urllib.request
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


class SameWorkbookTests(unittest.TestCase):
    def test_matches_etag_quotes_and_s3_fields(self) -> None:
        marker = {"id": "abc", "updated_at": "2026-09-25T00:00:00Z", "size": 100}
        asset = {"ETag": '"abc"', "LastModified": "2026-09-25T00:00:00Z", "ContentLength": "100"}
        self.assertTrue(fresh.same_workbook(marker, asset))

    def test_size_or_id_change_cooks(self) -> None:
        marker = {"id": "abc", "updated_at": "t", "size": 100}
        self.assertFalse(fresh.same_workbook(marker, {"id": "abc", "updated_at": "t", "size": 101}))
        self.assertFalse(fresh.same_workbook(marker, {"id": "def", "updated_at": "t", "size": 100}))
        self.assertFalse(fresh.same_workbook(None, marker))
        self.assertFalse(fresh.same_workbook({}, marker))


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

    def test_head_failure_is_missing_not_raised(self) -> None:
        def fake_urlopen(req, timeout=0):
            raise urllib.error.HTTPError(req.full_url, 403, "Forbidden", hdrs=None, fp=io.BytesIO(b""))

        with mock.patch.object(fresh.urllib.request, "urlopen", fake_urlopen):
            with mock.patch("sys.stdout", new=io.StringIO()) as out:
                updated, nbytes = fresh.head_pack(LIVE_HOST)
        self.assertEqual((updated, nbytes), ("", 0))
        self.assertIn("403", out.getvalue())

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


if __name__ == "__main__":
    unittest.main()
