#!/usr/bin/env python3
"""Send one lock-screen alert after a Heartbeat pack publish.

No-ops with exit 0 when the APNs key is missing, so the cook never fails
because push is not set up. Prints `push skipped: no key` in that case.
"""

from __future__ import annotations

import base64
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from zoneinfo import ZoneInfo


BUNDLE_DEFAULT = "com.corymurray.FulfillmentHeartbeat"
TEAM_DEFAULT = "M7FL68Q43A"
SKIP_NO_KEY = "push skipped: no key"


def main(argv: list[str]) -> int:
    key_pem = os.environ.get("APNS_KEY_P8", "").strip()
    key_id = os.environ.get("APNS_KEY_ID", "").strip()
    if not key_pem or not key_id:
        print(SKIP_NO_KEY)
        return 0
    team = os.environ.get("APNS_TEAM_ID", "").strip() or TEAM_DEFAULT
    bundle = os.environ.get("APNS_BUNDLE_ID", "").strip() or BUNDLE_DEFAULT
    worker = os.environ.get("PUSH_WORKER_URL", "").strip().rstrip("/")
    secret = os.environ.get("PUSH_LIST_SECRET", "").strip()
    if not worker or not secret:
        print("push skipped: no worker")
        return 0
    pack = argv[1] if len(argv) > 1 else ""
    if not pack:
        print("push skipped: no pack path")
        return 0
    try:
        stamp = pack_stamp(pack)
    except Exception as error:
        print(f"push skipped: {error}")
        return 0
    if not stamp:
        print("push skipped: no pack timestamp")
        return 0
    if already_sent(worker, secret, stamp):
        print(f"push skipped: already sent {stamp}")
        return 0
    clock = publish_clock(stamp)
    alert = f"Heartbeat: new data uploaded {clock}"
    try:
        jwt = apns_jwt(key_pem, key_id, team)
    except Exception as error:
        print(f"push skipped: {error}")
        return 0
    delivered = 0
    for scope, host in (
        ("sandbox", "api.sandbox.push.apple.com"),
        ("prod", "api.push.apple.com"),
    ):
        for device in list_tokens(worker, secret, scope):
            if not should_deliver(device):
                if device.get("optedOut") is True:
                    print(f"push skipped: opted out env={scope}")
                continue
            token = str(device.get("token") or "")
            status = send_alert(host, token, bundle, jwt, alert)
            if status == 410:
                delete_token(worker, secret, scope, token)
                print(f"push removed dead token env={scope}")
            elif status == 200:
                delivered += 1
            else:
                print(f"push apns status={status} env={scope}")
    mark_sent(worker, secret, stamp)
    print(f"push sent stamp={stamp} delivered={delivered} alert={alert}")
    return 0


def pack_stamp(path: str) -> str:
    """Same order as the Updated header: chrome publishedAt, then written_at."""
    con = sqlite3.connect(path)
    try:
        row = con.execute("SELECT json FROM dash_chrome WHERE id = 1").fetchone()
        if row and row[0]:
            chrome = json.loads(row[0])
            published = chrome.get("publishedAt")
            if isinstance(published, str) and published.strip():
                return published.strip()
        meta = con.execute("SELECT written_at FROM pack_meta LIMIT 1").fetchone()
        if meta and meta[0]:
            return str(meta[0]).strip()
    finally:
        con.close()
    return ""


def publish_clock(stamp: str) -> str:
    """`EEE M/d h:mm a` in APNS_DISPLAY_TZ (default America/Chicago).

    Built by hand so the cook runner (macOS) and a Linux laptop print the
    same clock. `%-m` is a glibc extension and raises on macOS.
    """
    text = stamp.replace("Z", "+00:00")
    when = datetime.fromisoformat(text)
    if when.tzinfo is None:
        when = when.replace(tzinfo=ZoneInfo("UTC"))
    zone = os.environ.get("APNS_DISPLAY_TZ", "").strip() or "America/Chicago"
    local = when.astimezone(ZoneInfo(zone))
    weekday = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")[local.weekday()]
    hour = local.hour % 12 or 12
    ampm = "AM" if local.hour < 12 else "PM"
    return f"{weekday} {local.month}/{local.day} {hour}:{local.minute:02d} {ampm}"


def already_sent(worker: str, secret: str, stamp: str) -> bool:
    query = urllib.parse.urlencode({"stamp": stamp})
    payload = worker_json("GET", f"{worker}/sent?{query}", secret)
    return bool(payload.get("sent"))


def mark_sent(worker: str, secret: str, stamp: str) -> None:
    worker_json("PUT", f"{worker}/sent", secret, {"stamp": stamp})


def should_deliver(device: dict) -> bool:
    """Opted-out phones stay in KV so the toggle can turn back on. Do not alert them."""
    token = str(device.get("token") or "").strip()
    if not token:
        return False
    return device.get("optedOut") is not True


def list_tokens(worker: str, secret: str, scope: str) -> list[dict]:
    query = urllib.parse.urlencode({"env": scope})
    payload = worker_json("GET", f"{worker}/tokens?{query}", secret)
    tokens = payload.get("tokens")
    return tokens if isinstance(tokens, list) else []


def delete_token(worker: str, secret: str, scope: str, token: str) -> None:
    query = urllib.parse.urlencode({"env": scope, "token": token})
    worker_json("DELETE", f"{worker}/token?{query}", secret)


def worker_json(method: str, url: str, secret: str, body: dict | None = None) -> dict:
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header("Authorization", f"Bearer {secret}")
    if data is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")
        raise RuntimeError(f"worker {method} {error.code} {detail}") from error
    if not raw:
        return {}
    parsed = json.loads(raw)
    return parsed if isinstance(parsed, dict) else {}


def apns_jwt(key_pem: str, key_id: str, team_id: str) -> str:
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id}, separators=(",", ":")).encode())
    payload = b64url(
        json.dumps({"iss": team_id, "iat": int(datetime.now().timestamp())}, separators=(",", ":")).encode()
    )
    signing = f"{header}.{payload}".encode()
    pem = key_pem.replace("\\n", "\n")
    if not pem.endswith("\n"):
        pem += "\n"
    with tempfile.NamedTemporaryFile("w", delete=False) as handle:
        handle.write(pem)
        key_path = handle.name
    try:
        der = subprocess.check_output(
            ["openssl", "dgst", "-sha256", "-sign", key_path],
            input=signing,
        )
    finally:
        os.remove(key_path)
    return f"{header}.{payload}.{b64url(der_to_raw(der))}"


def send_alert(host: str, token: str, bundle: str, jwt: str, alert: str) -> int:
    body = json.dumps({"aps": {"alert": alert, "sound": "default"}}).encode()
    url = f"https://{host}/3/device/{token}"
    result = subprocess.run(
        [
            "curl",
            "--http2",
            "--silent",
            "--show-error",
            "--output",
            "/dev/null",
            "--write-out",
            "%{http_code}",
            "--max-time",
            "20",
            "-X",
            "POST",
            "-H",
            f"authorization: bearer {jwt}",
            "-H",
            f"apns-topic: {bundle}",
            "-H",
            "apns-push-type: alert",
            "-H",
            "apns-priority: 10",
            "--data-binary",
            "@-",
            url,
        ],
        input=body,
        capture_output=True,
    )
    text = (result.stdout or b"").decode().strip()
    if not text.isdigit():
        return 0
    return int(text)


def der_to_raw(sig: bytes) -> bytes:
    if not sig or sig[0] != 0x30:
        raise ValueError("APNs signature was not DER")
    index = 2
    if sig[1] & 0x80:
        index = 2 + (sig[1] & 0x7F)

    def read_int(at: int) -> tuple[bytes, int]:
        if sig[at] != 0x02:
            raise ValueError("APNs signature integer missing")
        length = sig[at + 1]
        start = at + 2
        return sig[start : start + length], start + length

    raw_r, index = read_int(index)
    raw_s, _ = read_int(index)

    def pad(value: bytes) -> bytes:
        value = value.lstrip(b"\x00")
        if len(value) > 32:
            raise ValueError("APNs signature integer too wide")
        return value.rjust(32, b"\x00")

    return pad(raw_r) + pad(raw_s)


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except Exception as error:
        print(f"push skipped: {error}")
        raise SystemExit(0)
