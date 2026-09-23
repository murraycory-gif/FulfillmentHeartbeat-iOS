#!/usr/bin/env python3
"""Workbook vs LIVE pack freshness for the cook.

Public HEAD of current.sqlite is 200 from a normal client. GitHub Actions
can get 403 on that HEAD (r2.dev rejects User-Agent Python-urllib, and the
runner WAF can block HEAD). That 403 is a warning. It must not raise, must
not skip the cook, and must not block publish.

After a failed HEAD, try GET Range bytes=0-0, then aws s3api head-object
when R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ACCOUNT_ID, and R2_BUCKET
are set. If those miss too, pack_bytes stays 0 and the cook still runs.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import urllib.error
import urllib.request

# r2.dev rejects "Python-urllib/…". Any other non-empty agent is accepted.
PACK_USER_AGENT = "HeartbeatCook/1.0"
R2_SECRET_NAMES = (
    "R2_ACCESS_KEY_ID",
    "R2_SECRET_ACCESS_KEY",
    "R2_ACCOUNT_ID",
    "R2_BUCKET",
)


def head_pack(pack_host: str, object_key: str = "current.sqlite", timeout: int = 20) -> tuple[str, int]:
    """Return (Last-Modified, byte size). Missing object is ("", 0), never an exception."""
    host = (pack_host or "").rstrip("/")
    if not host:
        print(f"R2 HEAD {object_key}: PACK_HOST is empty. pack_bytes=0. Not skipping. Cook continues.")
        return "", 0
    url = f"{host}/{object_key}"
    got = _public_meta(url, object_key, method="HEAD", timeout=timeout)
    if got is not None:
        return got
    print(f"R2 HEAD {object_key} failed. Trying GET Range bytes=0-0.")
    got = _public_meta(url, object_key, method="GET", timeout=timeout, range_header="bytes=0-0")
    if got is not None:
        return got
    print(f"R2 GET Range {object_key} failed. Trying aws s3api head-object.")
    got = _s3api_head(object_key)
    if got is not None:
        return got
    print(f"R2 size unknown for {object_key}. pack_bytes=0. Not skipping. Cook continues.")
    return "", 0


def should_skip_cook(force: bool, xlsx_dt, pack_dt, pack_bytes: int) -> bool:
    """Skip only when a real pack is already newer than the workbook.

    A failed HEAD/GET/s3api leaves pack_bytes at 0. That must not skip.
    workflow_dispatch (force) always cooks.
    """
    if force or pack_bytes < 1_000_000 or xlsx_dt is None or pack_dt is None:
        return False
    return xlsx_dt <= pack_dt


def listed_size(rows, name: str) -> int:
    """Byte size of `name` in a Supabase storage list, or -1 if missing.

    Accepts a list of row objects, or the cook's name→row dict via .get(name).
    A string row, a string error body, or an error object is missing — it does not raise.
    """
    if isinstance(rows, dict):
        direct = rows.get(name)
        if isinstance(direct, dict):
            size = _row_size(direct, name)
            if size is not None:
                return size
            # Key matched. The value is the row even if its name field differs.
            return _size_from_sources(direct)
        if not any(isinstance(value, dict) for value in rows.values()):
            return -1
        rows = [value for value in rows.values() if isinstance(value, dict)]
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


def _public_meta(url: str, object_key: str, method: str, timeout: int, range_header: str = "") -> tuple[str, int] | None:
    headers = {"User-Agent": PACK_USER_AGENT}
    if range_header:
        headers["Range"] = range_header
    req = urllib.request.Request(url, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            updated = resp.headers.get("Last-Modified") or ""
            if range_header:
                nbytes = _total_from_content_range(resp.headers.get("Content-Range") or "")
            else:
                nbytes = _int_or_none(resp.headers.get("Content-Length"))
            if nbytes is None or nbytes < 1:
                print(f"R2 {method} {object_key}: no byte size in the response")
                return None
            return updated, nbytes
    except urllib.error.HTTPError as exc:
        print(f"R2 {method} {object_key}: HTTP {exc.code} {exc.reason}")
        return None
    except Exception as exc:
        print(f"R2 {method} {object_key}: {exc}")
        return None


def _total_from_content_range(header: str) -> int | None:
    # "bytes 0-0/32198656". The response Content-Length is 1, not the object size.
    if "/" not in (header or ""):
        return None
    return _int_or_none(header.rsplit("/", 1)[-1].strip())


def _int_or_none(raw) -> int | None:
    if raw is None or raw == "*":
        return None
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None


def _s3api_head(object_key: str) -> tuple[str, int] | None:
    missing = [name for name in R2_SECRET_NAMES if not os.environ.get(name)]
    if missing:
        print("R2 s3api head-object skipped. Unset GitHub secrets: " + " ".join(missing))
        return None
    if shutil.which("aws") is None:
        print("R2 s3api head-object skipped. aws CLI is not installed.")
        return None
    endpoint = f"https://{os.environ['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com"
    env = os.environ.copy()
    env["AWS_ACCESS_KEY_ID"] = os.environ["R2_ACCESS_KEY_ID"]
    env["AWS_SECRET_ACCESS_KEY"] = os.environ["R2_SECRET_ACCESS_KEY"]
    env["AWS_DEFAULT_REGION"] = env.get("AWS_DEFAULT_REGION") or "auto"
    env["AWS_EC2_METADATA_DISABLED"] = "true"
    try:
        proc = subprocess.run(
            [
                "aws",
                "s3api",
                "head-object",
                "--bucket",
                os.environ["R2_BUCKET"],
                "--key",
                object_key,
                "--endpoint-url",
                endpoint,
            ],
            capture_output=True,
            text=True,
            timeout=30,
            env=env,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        print(f"R2 s3api head-object: {exc}")
        return None
    if proc.returncode != 0:
        print(f"R2 s3api head-object failed (exit {proc.returncode}).")
        return None
    try:
        payload = json.loads(proc.stdout or "")
    except json.JSONDecodeError:
        print("R2 s3api head-object: response was not JSON")
        return None
    if not isinstance(payload, dict):
        print("R2 s3api head-object: response was not an object")
        return None
    nbytes = _int_or_none(payload.get("ContentLength"))
    updated = payload.get("LastModified") or ""
    if nbytes is None or nbytes < 1:
        print("R2 s3api head-object: no ContentLength")
        return None
    return str(updated), nbytes


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


def _size_from_sources(row: dict) -> int:
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


def _row_size(row: dict, name: str) -> int | None:
    if row.get("name") != name:
        return None
    return _size_from_sources(row)
