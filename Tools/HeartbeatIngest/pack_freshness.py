#!/usr/bin/env python3
"""Workbook vs LIVE pack freshness for the cook.

Public r2.dev HEAD does not use R2 credentials. Cloudflare returns 403 for
the default Python-urllib User-Agent and 200 for any other User-Agent.
"""
from __future__ import annotations

import json
import urllib.request

# r2.dev rejects "Python-urllib/…". Any other non-empty agent is accepted.
PACK_USER_AGENT = "HeartbeatCook/1.0"


def head_pack(pack_host: str, object_key: str = "current.sqlite", timeout: int = 20) -> tuple[str, int]:
    """Return (Last-Modified, Content-Length) for the public pack object.

    A failed HEAD prints the error and returns ("", 0) so the cook can still
    download the workbook. An empty host is missing, not an exception.
    """
    host = (pack_host or "").rstrip("/")
    if not host:
        print(f"R2 HEAD {object_key}: PACK_HOST is empty")
        return "", 0
    url = f"{host}/{object_key}"
    req = urllib.request.Request(
        url,
        method="HEAD",
        headers={"User-Agent": PACK_USER_AGENT},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            updated = resp.headers.get("Last-Modified") or ""
            raw_len = resp.headers.get("Content-Length") or 0
            try:
                nbytes = int(raw_len)
            except (TypeError, ValueError):
                nbytes = 0
            return updated, nbytes
    except Exception as exc:
        print(f"R2 HEAD {object_key}: {exc}")
        return "", 0


def workbook_identity(asset: dict | None) -> dict[str, object]:
    """Normalize a workbook marker or object head to id, updated_at, and size.

    Accepts GitHub release fields (id, updated_at, size) and S3 HeadObject
    fields (ETag, LastModified, ContentLength). Empty input is an empty identity.
    """
    if not isinstance(asset, dict):
        return {"id": "", "updated_at": "", "size": 0}
    raw_id = asset.get("id")
    if raw_id is None:
        raw_id = asset.get("etag")
    if raw_id is None:
        raw_id = asset.get("ETag")
    raw_updated = asset.get("updated_at")
    if raw_updated is None:
        raw_updated = asset.get("last_modified")
    if raw_updated is None:
        raw_updated = asset.get("LastModified")
    raw_size = asset.get("size")
    if raw_size is None:
        raw_size = asset.get("ContentLength")
    try:
        size = int(raw_size)
    except (TypeError, ValueError):
        size = 0
    return {
        "id": str(raw_id or "").strip().strip('"'),
        "updated_at": str(raw_updated or "").strip(),
        "size": size,
    }


def same_workbook(marker: dict | None, asset: dict | None) -> bool:
    """True when the cooked marker and the workbook object are the same bytes.

    A missing marker, a missing id, or any difference in id / updated_at / size
    means the cook should run. Comparison is exact after identity normalization.
    """
    left = workbook_identity(marker)
    right = workbook_identity(asset)
    if not left["id"] or not right["id"]:
        return False
    if left["size"] < 1 or right["size"] < 1:
        return False
    return left == right


def listed_size(rows, name: str) -> int:
    """Byte size of `name` in a Supabase storage list, or -1 if missing.

    Accepts a list of row objects or the cook's name→row dict. A string row,
    a string error body, or an error object is missing — it does not raise.
    """
    seq = _as_rows(rows)
    if seq is None:
        return -1
    for row in seq:
        if not isinstance(row, dict):
            continue
        size = _row_size(row, name)
        if size is not None:
            return size
    return -1


def _as_rows(rows):
    if isinstance(rows, str) or rows is None:
        return None
    if isinstance(rows, dict):
        if isinstance(rows.get("name"), str):
            return [rows]
        values = list(rows.values())
        if values and all(isinstance(value, dict) for value in values):
            return values
        return None
    if isinstance(rows, list):
        return rows
    return None


def _meta_dict(row: dict) -> dict:
    meta = row.get("metadata")
    if isinstance(meta, str):
        try:
            meta = json.loads(meta)
        except json.JSONDecodeError:
            return {}
    if isinstance(meta, dict):
        return meta
    return {}


def _row_size(row: dict, name: str) -> int | None:
    if row.get("name") != name:
        return None
    meta = _meta_dict(row)
    for source in (meta, row):
        for key in ("size", "contentLength"):
            raw = source.get(key)
            if raw is None:
                continue
            try:
                return int(raw)
            except (TypeError, ValueError):
                continue
    return 0
