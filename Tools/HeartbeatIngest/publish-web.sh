#!/bin/bash
# Extract a cooked current.sqlite and deploy the website.
# Cloudflare Pages project is fulfillment-heartbeat-web and nothing else.
# Token comes from CLOUDFLARE_API_TOKEN or ~/.config/heartbeat/cloudflare-api-token.
# This script never prints the token. A failed check does not deploy.
#
# A cook passes the sqlite. HEARTBEAT_UI_ONLY=1 skips that extract so a UI
# deploy does not bake an older pack over /data. An older sqlite does not
# replace a newer pack already in web/public/data. When
# ~/.config/heartbeat/web-email and web-password exist, a newer live pack is
# downloaded through the sign-in form first. After deploy, an unsigned
# /data request must be 401 JSON {"error":"unauthorized"} with no cookie.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SQLITE="${1:-}"
PROJECT="fulfillment-heartbeat-web"
SITE_URL="${HEARTBEAT_SITE_URL:-https://fulfillment-heartbeat-web.pages.dev}"
UI_ONLY="${HEARTBEAT_UI_ONLY:-}"
USE_LOCAL="${HEARTBEAT_USE_LOCAL_DATA:-}"

if [[ "${HEARTBEAT_PAGES_PROJECT:-$PROJECT}" != "$PROJECT" ]]; then
  echo "Refusing Pages project '${HEARTBEAT_PAGES_PROJECT}'. Only ${PROJECT} is allowed." >&2
  exit 1
fi

if [[ -z "${HEARTBEAT_SKIP_GIT_CHECK:-}" ]]; then
  git -C "$ROOT" fetch origin
  BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  if ! git -C "$ROOT" rev-parse --verify --quiet "origin/${BRANCH}" >/dev/null; then
    echo "refusing publish: origin/${BRANCH} is missing after fetch" >&2
    exit 1
  fi
  BEHIND="$(git -C "$ROOT" rev-list --count "HEAD..origin/${BRANCH}")"
  if [[ "$BEHIND" -gt 0 ]]; then
    echo "refusing publish: ${BRANCH} is ${BEHIND} commit(s) behind origin/${BRANCH}" >&2
    exit 1
  fi
fi
DATA_ONLY="${HEARTBEAT_DATA_ONLY:-}"
if [[ -z "$UI_ONLY" && ( -z "$SQLITE" || ! -f "$SQLITE" ) ]]; then
  echo "publish-web: cooked sqlite is missing" >&2
  exit 1
fi

TOKEN_FILE="${HEARTBEAT_CF_TOKEN_FILE:-$HOME/.config/heartbeat/cloudflare-api-token}"
if [[ -z "${CLOUDFLARE_API_TOKEN:-}" && -f "$TOKEN_FILE" ]]; then
  CLOUDFLARE_API_TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
  export CLOUDFLARE_API_TOKEN
fi
if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  echo "CLOUDFLARE_API_TOKEN is unset and ${TOKEN_FILE} is missing. Not deploying." >&2
  exit 1
fi

WEB="$ROOT/web"
DATA="$WEB/public/data"
CONFIG_DIR="${HOME}/.config/heartbeat"
EMAIL_FILE="${HEARTBEAT_WEB_EMAIL_FILE:-$CONFIG_DIR/web-email}"
PASS_FILE="${HEARTBEAT_WEB_PASSWORD_FILE:-$CONFIG_DIR/web-password}"

if [[ -z "$UI_ONLY" ]]; then
  EXTRACT="$(mktemp -d)"
  DAILY_XLSX="${HEARTBEAT_DAILY_XLSX:-}"
  if [[ -n "$DAILY_XLSX" && -f "$DAILY_XLSX" ]]; then
    python3 "$ROOT/web/scripts/extract_web_pack.py" "$SQLITE" "$EXTRACT" "$DAILY_XLSX"
  else
    python3 "$ROOT/web/scripts/extract_web_pack.py" "$SQLITE" "$EXTRACT"
  fi
  python3 - "$DATA" "$EXTRACT" << 'PY'
import json, shutil, sys
from pathlib import Path

dest = Path(sys.argv[1])
fresh = Path(sys.argv[2])

def stamp(root):
    home = root / "home.json"
    if not home.is_file():
        return ""
    return str(json.loads(home.read_text()).get("publishedAt") or "")

have = stamp(dest)
cooked = stamp(fresh)
if have and cooked < have:
    print(f"keeping newer pack publishedAt={have} (sqlite is {cooked})")
    raise SystemExit(0)
if dest.exists():
    shutil.rmtree(dest)
shutil.copytree(fresh, dest)
print(f"using sqlite pack publishedAt={cooked}")
PY
  rm -rf "$EXTRACT"
else
  echo "UI-only deploy: not extracting sqlite"
fi

LIVE_CHECKED=0
if [[ -s "$EMAIL_FILE" && -s "$PASS_FILE" ]]; then
  python3 - "$DATA" "$EMAIL_FILE" "$PASS_FILE" "$SITE_URL" << 'PY'
import http.cookiejar
import json
import shutil
import sys
import urllib.parse
import urllib.request
from pathlib import Path

dest = Path(sys.argv[1])
email = Path(sys.argv[2]).read_text().strip()
password = Path(sys.argv[3]).read_text().strip()
site = sys.argv[4].rstrip("/")
ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

def stamp(root):
    home = root / "home.json"
    if not home.is_file():
        return ""
    return str(json.loads(home.read_text()).get("publishedAt") or "")

jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))

def call(path, data=None):
    body = urllib.parse.urlencode(data).encode() if data is not None else None
    req = urllib.request.Request(
        site + path,
        data=body,
        headers={
            "User-Agent": ua,
            "Accept": "application/json,text/html",
            "Origin": site,
        },
        method="POST" if data is not None else "GET",
    )
    with opener.open(req) as res:
        return res.status, res.read()

try:
    call("/login", {"email": email, "password": password})
    status, raw = call("/data/home.json")
except Exception as error:
    print(f"live pack check failed: {error.__class__.__name__}", file=sys.stderr)
    raise SystemExit(2)
if status != 200:
    print(f"live pack check failed: /data/home.json returned {status}", file=sys.stderr)
    raise SystemExit(2)
live = json.loads(raw)
live_stamp = str(live.get("publishedAt") or "")
local_stamp = stamp(dest)
if not live_stamp or live_stamp <= local_stamp:
    print(f"local pack publishedAt={local_stamp or 'missing'} is current (live {live_stamp or 'missing'})")
    raise SystemExit(0)
names = [path.relative_to(dest).as_posix() for path in dest.rglob("*") if path.is_file()]
if "home.json" not in names:
    names.insert(0, "home.json")
staged = dest.parent / ".data-next"
if staged.exists():
    shutil.rmtree(staged)
staged.mkdir()
for name in names:
    status, payload = call("/data/" + name)
    if status != 200 or not payload:
        shutil.rmtree(staged, ignore_errors=True)
        print(f"live pack check failed: /data/{name} returned {status}", file=sys.stderr)
        raise SystemExit(2)
    target = staged / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(payload)
got = stamp(staged)
if got != live_stamp:
    shutil.rmtree(staged, ignore_errors=True)
    print("live pack check failed: downloaded stamp does not match", file=sys.stderr)
    raise SystemExit(2)
backup = dest.parent / ".data-prev"
if backup.exists():
    shutil.rmtree(backup)
if dest.exists():
    dest.rename(backup)
staged.rename(dest)
if backup.exists():
    shutil.rmtree(backup)
print(f"fetched live pack publishedAt={got}")
PY
  LIVE_CHECKED=1
fi

if [[ -n "$UI_ONLY" && "$LIVE_CHECKED" -ne 1 && "$USE_LOCAL" != "1" ]]; then
  echo "publish-web: UI-only deploy needs the current pack in web/public/data (HEARTBEAT_USE_LOCAL_DATA=1) or a site login in ${EMAIL_FILE} and ${PASS_FILE}." >&2
  exit 1
fi

node "$WEB/check_pack.mjs" "$DATA"

python3 - "$DATA" << 'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
home = json.loads((root / "home.json").read_text())
schedule = json.loads((root / "schedule.json").read_text())
published = str(home.get("publishedAt") or "")
if len(published) < 20 or published.startswith("2026-09-29") or published.startswith("2026-09-30"):
    raise SystemExit(f"refusing deploy: publishedAt {published!r}")
if len(home.get("summaries") or []) < 12:
    raise SystemExit("refusing deploy: dashboard summaries are incomplete")
week = int(schedule.get("week") or 0)
stores = schedule.get("stores") or []
if week <= 0 or len(stores) < 1000:
    raise SystemExit(f"refusing deploy: schedule week={week} stores={len(stores)}")
found = False
for line in home.get("regionLines") or []:
    if line.get("section") != "dynacap":
        continue
    for child in line.get("children") or []:
        if child.get("division") != "Mid-Atlantic":
            continue
        found = True
        rate = float(str(child.get("value")).replace(",", ""))
        health = child.get("health")
        expect = "good" if rate >= 65 else "watch" if rate >= 60 else "risk"
        if health != expect:
            raise SystemExit(
                f"refusing deploy: Mid-Atlantic {rate} cooked health {health}, band expects {expect}"
            )
if not found:
    raise SystemExit("refusing deploy: cooked pack has no Mid-Atlantic dynacap line")
print(f"pack ok publishedAt={published} week={week} stores={len(stores)}")
PY

if grep -q "dynacapHealth" "$WEB/public/seat.js"; then
  echo "refusing deploy: seat.js still overrides dynacap health" >&2
  exit 1
fi

cd "$WEB"
npm test

# The upload is dist/, after the test stages public/ into it. Check those files.
node "$WEB/scripts/print_pack_stamp.mjs" "$WEB/dist/data"
node "$WEB/check_pack.mjs" "$WEB/dist/data"

# Session and setup secrets are created once. A later deploy must not rotate them.
SECRET_LIST="$(npx wrangler pages secret list --project-name "$PROJECT" 2>/dev/null || true)"
put_secret_if_missing() {
  local name="$1"
  local file="$2"
  if grep -q "$name" <<<"$SECRET_LIST"; then
    return
  fi
  if [[ ! -s "$file" ]]; then
    echo "publish-web: ${file} is missing, so ${name} was not uploaded" >&2
    return
  fi
  npx wrangler pages secret put "$name" --project-name "$PROJECT" < "$file"
}
mkdir -p "$CONFIG_DIR"
umask 077
SESSION_FILE="${HEARTBEAT_SESSION_SECRET_FILE:-$CONFIG_DIR/session-secret}"
SETUP_FILE="${HEARTBEAT_SETUP_SECRET_FILE:-$CONFIG_DIR/setup-secret}"
ADMIN_FILE="${HEARTBEAT_ADMIN_EMAIL_FILE:-$CONFIG_DIR/admin-email}"
if [[ ! -s "$SESSION_FILE" ]]; then
  openssl rand -base64 32 > "$SESSION_FILE"
fi
if [[ ! -s "$SETUP_FILE" ]]; then
  openssl rand -base64 32 > "$SETUP_FILE"
fi
put_secret_if_missing SESSION_SECRET "$SESSION_FILE"
put_secret_if_missing SETUP_SECRET "$SETUP_FILE"
put_secret_if_missing ADMIN_EMAIL "$ADMIN_FILE"

node "$WEB/scripts/print_pack_stamp.mjs" "$DATA"

if [[ -n "$DATA_ONLY" ]]; then
  python3 - "$DATA" << 'PY'
import json, re, subprocess, sys, tempfile
from pathlib import Path

root = Path(sys.argv[1])
files = sorted(path for path in root.rglob("*.json") if path.is_file())
if not files:
    raise SystemExit("data-only upload: no pack json")
home_path = root / "home.json"
if not home_path.is_file():
    raise SystemExit("data-only upload: home.json is missing")
home = json.loads(home_path.read_text())
sha = str((home.get("metadata") or {}).get("cookSha") or "")
if not re.fullmatch(r"[0-9a-f]{40}", sha):
    raise SystemExit("data-only upload: cookSha missing")

def wrangler(args, check=True):
    return subprocess.run(["npx", "wrangler", *args], check=check)

for path in files:
    rel = path.relative_to(root).as_posix()
    key = f"heartbeat-packs/web-pack/packs/{sha}/{rel}"
    wrangler(["r2", "object", "put", key, f"--file={path}", "--remote"])

previous = ""
with tempfile.TemporaryDirectory() as tmp:
    pointer_file = Path(tmp) / "pointer.json"
    got = wrangler(
        ["r2", "object", "get", "heartbeat-packs/web-pack/pointer.json", f"--file={pointer_file}", "--remote"],
        check=False,
    )
    if got.returncode == 0 and pointer_file.is_file():
        try:
            old = json.loads(pointer_file.read_text())
        except json.JSONDecodeError:
            old = {}
        current = str(old.get("current") or "")
        if re.fullmatch(r"[0-9a-f]{40}", current) and current != sha:
            previous = current
        else:
            kept = str(old.get("previous") or "")
            if re.fullmatch(r"[0-9a-f]{40}", kept):
                previous = kept
    new_pointer = Path(tmp) / "next-pointer.json"
    new_pointer.write_text(json.dumps({"current": sha, "previous": previous}))
    wrangler(["r2", "object", "put", "heartbeat-packs/web-pack/pointer.json", f"--file={new_pointer}", "--remote"])

print(f"data-only upload: {len(files)} pack files at web-pack/packs/{sha}/, pointer updated, site tree not deployed")
PY
  exit 0
fi

npx wrangler pages deploy dist \
  --project-name "$PROJECT" \
  --branch main \
  --commit-dirty=true

python3 - "$SITE_URL" << 'PY'
import sys
import urllib.error
import urllib.request

site = sys.argv[1].rstrip("/")
ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

def fetch(path):
    req = urllib.request.Request(site + path, headers={"User-Agent": ua, "Accept": "application/json,text/html"})
    try:
        with urllib.request.urlopen(req) as res:
            status, header_items, payload = res.status, res.headers.items(), res.read()
    except urllib.error.HTTPError as error:
        status, header_items, payload = error.code, error.headers.items(), error.read()
    return status, {key.lower(): value for key, value in header_items}, payload

status, headers, raw = fetch("/data/home.json")
body = raw.decode()
cache = headers.get("cache-control", "")
if status != 401 or body != '{"error":"unauthorized"}':
    raise SystemExit(f"refusing: unsigned /data/home.json is {status}")
if "private" not in cache or "no-store" not in cache:
    raise SystemExit(f"refusing: /data cache-control is {cache!r}")
if "set-cookie" in headers or "www-authenticate" in headers:
    raise SystemExit("refusing: unsigned /data set a cookie or asked for basic auth")
login_status, _, login = fetch("/login")
login_html = login.decode("utf-8", "replace")
if (
    login_status != 200
    or 'autocomplete="username"' not in login_html
    or 'name="email"' not in login_html
    or 'type="text"' not in login_html
    or 'inputmode="email"' not in login_html
    or "Email or username" not in login_html
    or 'type="email"' in login_html
):
    raise SystemExit("refusing: /login must accept a username or an email")
print('gate ok unsigned /data {"error":"unauthorized"}')
PY

# The upload already happened. Read the live files back through sign-in and
# compare them to dist/data, which is what wrangler just uploaded.
if [[ -s "$EMAIL_FILE" && -s "$PASS_FILE" ]]; then
  python3 - "$SITE_URL" "$EMAIL_FILE" "$PASS_FILE" "$WEB/dist/data" << 'PY'
import http.cookiejar
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

site = sys.argv[1].rstrip("/")
email = Path(sys.argv[2]).read_text().strip()
password = Path(sys.argv[3]).read_text().strip()
root = Path(sys.argv[4])
ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
files = sorted(path.relative_to(root).as_posix() for path in root.rglob("*.json") if path.is_file())
if not files:
    raise SystemExit("signed-in compare: dist data has no json")

jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))

def call(path, data=None):
    body = urllib.parse.urlencode(data).encode() if data is not None else None
    req = urllib.request.Request(
        site + path,
        data=body,
        headers={
            "User-Agent": ua,
            "Accept": "application/json,text/html",
            "Origin": site,
        },
        method="POST" if data is not None else "GET",
    )
    try:
        with opener.open(req) as res:
            return res.status, res.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()

status, _ = call("/login", {"email": email, "password": password})
if status not in (200, 302, 303):
    raise SystemExit(f"signed-in compare: login returned {status}")
for rel in files:
    local = json.loads((root / rel).read_text())
    status, raw = call("/data/" + rel)
    if status != 200:
        raise SystemExit(f"signed-in compare: /data/{rel} returned {status}")
    try:
        live = json.loads(raw)
    except json.JSONDecodeError:
        raise SystemExit(f"signed-in compare: /data/{rel} was not json")
    for key in ("publishedAt", "schemaVersion", "cookSha"):
        if live.get(key) != local.get(key):
            raise SystemExit(
                f"signed-in compare: /data/{rel} {key}={live.get(key)!r} uploaded {local.get(key)!r}"
            )
    print(f"live {rel} publishedAt={live.get('publishedAt')} schemaVersion={live.get('schemaVersion')} cookSha={live.get('cookSha')}")
print(f"signed-in pack matches {len(files)} files")
PY
else
  echo "publish-web: signed-in compare needs ${EMAIL_FILE} and ${PASS_FILE}; dist stamps were printed above" >&2
fi
