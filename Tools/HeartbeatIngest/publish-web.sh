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
DATA_ONLY="${HEARTBEAT_DATA_ONLY:-}"
USE_LOCAL="${HEARTBEAT_USE_LOCAL_DATA:-}"
# UI-only skips the local pack check and does not move the pointer.
# A dirty tree still refuses, so the build label matches the files that ship.
# A data publish refuses every path.
if [[ -n "$UI_ONLY" && -z "$DATA_ONLY" ]]; then
  if ! bash "$ROOT/Tools/HeartbeatIngest/cook-guard.sh" --publish; then
    echo "refusing publish: cook guard" >&2
    exit 1
  fi
else
  if ! bash "$ROOT/Tools/HeartbeatIngest/cook-guard.sh" --publish-data; then
    echo "refusing publish: cook guard" >&2
    exit 1
  fi
fi

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
PACK_DIR="$DATA"
CONFIG_DIR="${HOME}/.config/heartbeat"
EMAIL_FILE="${HEARTBEAT_WEB_EMAIL_FILE:-$CONFIG_DIR/web-email}"
PASS_FILE="${HEARTBEAT_WEB_PASSWORD_FILE:-$CONFIG_DIR/web-password}"
EXTRACT=""
LIVE_STAGE=""
POINTER_PLAN=""
cleanup_stages() {
  if [[ -n "${EXTRACT}" ]]; then
    rm -rf "$EXTRACT"
  fi
  if [[ -n "${LIVE_STAGE}" ]]; then
    rm -rf "$LIVE_STAGE"
  fi
  if [[ -n "${POINTER_PLAN}" ]]; then
    rm -f "$POINTER_PLAN"
  fi
}
on_term() {
  cleanup_stages
  # SIGTERM to this shell alone used to leave pack_publish.py and one temp dir.
  pkill -TERM -P $$ >/dev/null 2>&1 || true
  exit 143
}
trap cleanup_stages EXIT
trap on_term TERM

if [[ -z "$UI_ONLY" ]]; then
  EXTRACT="$(mktemp -d)"
  DAILY_XLSX="${HEARTBEAT_DAILY_XLSX:-}"
  if [[ -n "$DAILY_XLSX" && -f "$DAILY_XLSX" ]]; then
    python3 "$ROOT/web/scripts/extract_web_pack.py" "$SQLITE" "$EXTRACT" "$DAILY_XLSX"
  else
    python3 "$ROOT/web/scripts/extract_web_pack.py" "$SQLITE" "$EXTRACT"
  fi
  set +e
  decision="$(python3 "$ROOT/web/scripts/pack_identity.py" prefer "$EXTRACT" "$DATA")"
  prefer_status=$?
  set -e
  if [[ "$prefer_status" -ne 0 || ( "$decision" != "replace" && "$decision" != "keep" ) ]]; then
    echo "refusing pack replace: cookSha and cookedAt disagree or cannot be ranked" >&2
    rm -rf "$EXTRACT"
    exit 1
  fi
  if [[ "$decision" == "replace" ]]; then
    # cookedAt changes on every cook. Copying that into tracked web/public/data
    # leaves the tree dirty and the next publish refuses. Upload from the extract.
    PACK_DIR="$EXTRACT"
    echo "publish-web: new cook stays out of tracked web/public/data"
    python3 "$ROOT/web/scripts/pack_identity.py" check "$PACK_DIR"
  else
    echo "keeping pack $(python3 "$ROOT/web/scripts/pack_identity.py" check "$DATA")"
    rm -rf "$EXTRACT"
  fi
else
  echo "UI-only deploy: not extracting sqlite"
fi

LIVE_CHECKED=0
LIVE_STAGE="$(mktemp -d)"
if [[ -n "$UI_ONLY" ]]; then
  echo "UI-only deploy: skipping local pack check"
elif [[ -s "$EMAIL_FILE" && -s "$PASS_FILE" ]]; then
  python3 - "$PACK_DIR" "$EMAIL_FILE" "$PASS_FILE" "$SITE_URL" "$ROOT/web/scripts/pack_identity.py" "$LIVE_STAGE" << 'PY'
import http.cookiejar
import json
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

dest = Path(sys.argv[1])
email = Path(sys.argv[2]).read_text().strip()
password = Path(sys.argv[3]).read_text().strip()
site = sys.argv[4].rstrip("/")
identity_script = sys.argv[5]
stage = Path(sys.argv[6])
ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

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
live_file = stage / ".live-home.json"
stage.mkdir(parents=True, exist_ok=True)
live_file.write_text(json.dumps(live), encoding="utf-8")
ranked = subprocess.run(
    [sys.executable, identity_script, "live", str(live_file), str(dest)],
    capture_output=True,
    text=True,
)
live_file.unlink(missing_ok=True)
choice = (ranked.stdout or "").strip()
if ranked.returncode != 0 or choice != "keep":
    print("live pack check refused: local pack is older or the stamps disagree", file=sys.stderr)
    raise SystemExit(2)
print(f"local pack cookSha={live.get('cookSha')} cookedAt={live.get('cookedAt') or 'missing'} is current")
PY
  LIVE_CHECKED=1
fi

# Every pack needs cookedAt, including the pinned live cook. The site may
# keep serving that cook. This script must not publish it again.
# UI-only does not re-check that local tree. It checks the live pointer instead.
if [[ -z "$UI_ONLY" ]]; then
if ! node "$WEB/check_pack.mjs" --cooked-at "$PACK_DIR"; then
  echo "refusing publish: cookedAt is missing" >&2
  exit 1
fi

node "$WEB/check_pack.mjs" "$PACK_DIR"

python3 - "$PACK_DIR" << 'PY'
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
fi

if grep -q "dynacapHealth" "$WEB/public/seat.js"; then
  echo "refusing deploy: seat.js still overrides dynacap health" >&2
  exit 1
fi

# Before tests and secret upload. A dirty tree would stamp the build label
# with a commit that does not match the files about to ship. HEARTBEAT_DATA_ONLY
# reaches this check too, so a dirty tree blocks a data-only upload.
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
  echo "refusing publish: git worktree is dirty, so the build label would show a commit that does not match this tree" >&2
  exit 1
fi

cd "$WEB"
npm test

# The test stages the tracked pack into dist/. A new cook is not that tree.
# Put it in dist only, which is gitignored, so the deployment matches the upload.
if [[ "$PACK_DIR" != "$DATA" ]]; then
  rm -rf "$WEB/dist/data"
  mkdir -p "$WEB/dist"
  cp -R "$PACK_DIR" "$WEB/dist/data"
fi

# The upload is dist/, after the test stages public/ into it. Check those files.
node "$WEB/scripts/print_pack_stamp.mjs" "$WEB/dist/data"
node "$WEB/check_pack.mjs" "$WEB/dist/data"

# BEGIN secrets
# Data-only publish never lists, creates, or uploads a Pages secret.
# A failed secret list aborts. It must not mint a new SESSION_SECRET.
if [[ -z "$DATA_ONLY" ]]; then
  if ! SECRET_LIST="$(npx wrangler pages secret list --project-name "$PROJECT" 2>/dev/null)"; then
    echo "refusing publish: Pages secret list failed, so no secret was created" >&2
    exit 1
  fi
  put_secret_if_missing() {
    local name="$1"
    local file="$2"
    if grep -Fq "$name" <<<"$SECRET_LIST"; then
      return 0
    fi
    if [[ ! -s "$file" ]]; then
      echo "refusing publish: ${file} is missing, so ${name} was not created" >&2
      exit 1
    fi
    npx wrangler pages secret put "$name" --project-name "$PROJECT" < "$file"
  }
  mkdir -p "$CONFIG_DIR"
  umask 077
  SESSION_FILE="${HEARTBEAT_SESSION_SECRET_FILE:-$CONFIG_DIR/session-secret}"
  SETUP_FILE="${HEARTBEAT_SETUP_SECRET_FILE:-$CONFIG_DIR/setup-secret}"
  ADMIN_FILE="${HEARTBEAT_ADMIN_EMAIL_FILE:-$CONFIG_DIR/admin-email}"
  if ! grep -Fq "SESSION_SECRET" <<<"$SECRET_LIST" && [[ ! -s "$SESSION_FILE" ]]; then
    openssl rand -base64 32 > "$SESSION_FILE"
  fi
  if ! grep -Fq "SETUP_SECRET" <<<"$SECRET_LIST" && [[ ! -s "$SETUP_FILE" ]]; then
    openssl rand -base64 32 > "$SETUP_FILE"
  fi
  put_secret_if_missing SESSION_SECRET "$SESSION_FILE"
  put_secret_if_missing SETUP_SECRET "$SETUP_FILE"
  put_secret_if_missing ADMIN_EMAIL "$ADMIN_FILE"
fi
# END secrets

node "$WEB/scripts/print_pack_stamp.mjs" "$PACK_DIR"

# A full deploy used to pages-deploy static JSON and leave current.json alone.
# Once a pointer exists, data has to move through that pointer or the deploy stops.
# UI-only does not upload. A missing pointer is not filled with the legacy pin.
# A full deploy uploads the objects first and moves current.json only after
# wrangler pages deploy exits 0. Data-only has no pages deploy, so it moves
# the pointer as the publish.
publish_pack_pointer() {
  python3 "$ROOT/web/scripts/pack_publish.py" "$PACK_DIR" "$WEB/check_pack.mjs"
}
pointer_is_verified() {
  local pointer_state
  pointer_state="$(python3 "$ROOT/web/scripts/pack_publish.py" preflight "$PACK_DIR")"
  printf '%s\n' "$pointer_state"
  [[ "$pointer_state" == "pointer preflight: verified" ]]
}
require_verified_pointer() {
  if ! pointer_is_verified; then
    echo "refusing deploy: pack data must publish through the pointer" >&2
    exit 1
  fi
}
fail_deploy_readback() {
  echo "deploy failed: the new UI is live and the pack pointer read-back failed, so the site is serving the new UI on the old data" >&2
  echo "rollback: cd \"$WEB\" && npx wrangler pages deployment rollback --project-name \"$PROJECT\"" >&2
  exit 1
}
if [[ -n "$DATA_ONLY" ]]; then
  publish_pack_pointer
elif [[ -z "$UI_ONLY" ]]; then
  POINTER_PLAN="$(mktemp)"
  python3 "$ROOT/web/scripts/pack_publish.py" --defer-pointer "$PACK_DIR" "$WEB/check_pack.mjs" "$POINTER_PLAN"
fi

if [[ -n "$DATA_ONLY" ]]; then
  require_verified_pointer
  if [[ -s "$EMAIL_FILE" && -s "$PASS_FILE" ]]; then
    python3 - "$SITE_URL" "$EMAIL_FILE" "$PASS_FILE" "$PACK_DIR" << 'PY'
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
    raise SystemExit("signed-in compare: data has no json")

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
            "Sec-Fetch-Site": "same-origin",
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
    keys = ["publishedAt", "schemaVersion", "cookSha", "cookedAt"]
    for key in keys:
        if live.get(key) != local.get(key):
            raise SystemExit(
                f"signed-in compare: /data/{rel} {key}={live.get(key)!r} uploaded {local.get(key)!r}"
            )
    print(f"live {rel} publishedAt={live.get('publishedAt')} cookedAt={live.get('cookedAt') or 'missing'} schemaVersion={live.get('schemaVersion')} cookSha={live.get('cookSha')}")
print(f"signed-in pack matches {len(files)} files")
PY
  else
    echo "publish-web: signed-in compare needs ${EMAIL_FILE} and ${PASS_FILE}; uploaded stamps were printed above" >&2
  fi
  exit 0
fi

if [[ -n "$UI_ONLY" ]]; then
  LIVE_POINTER_BEFORE="$(python3 "$ROOT/web/scripts/pack_publish.py" print-pointer)"
  echo "UI-only deploy: live pointer ${LIVE_POINTER_BEFORE}"
fi
npx wrangler pages deploy dist \
  --project-name "$PROJECT" \
  --branch main
if [[ -n "$POINTER_PLAN" ]]; then
  if ! python3 "$ROOT/web/scripts/pack_publish.py" --commit-pointer "$POINTER_PLAN"; then
    fail_deploy_readback
  fi
  if ! pointer_is_verified; then
    fail_deploy_readback
  fi
fi
if [[ -n "$UI_ONLY" ]]; then
  LIVE_POINTER_AFTER="$(python3 "$ROOT/web/scripts/pack_publish.py" print-pointer)"
  if [[ "$LIVE_POINTER_BEFORE" != "$LIVE_POINTER_AFTER" ]]; then
    echo "UI-only deploy changed the live pointer" >&2
    fail_deploy_readback
  fi
  echo "UI-only deploy: live pointer unchanged"
fi

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
    keys = ["publishedAt", "schemaVersion", "cookSha", "cookedAt"]
    for key in keys:
        if live.get(key) != local.get(key):
            raise SystemExit(
                f"signed-in compare: /data/{rel} {key}={live.get(key)!r} uploaded {local.get(key)!r}"
            )
    print(f"live {rel} publishedAt={live.get('publishedAt')} cookedAt={live.get('cookedAt') or 'missing'} schemaVersion={live.get('schemaVersion')} cookSha={live.get('cookSha')}")
print(f"signed-in pack matches {len(files)} files")
PY
else
  echo "publish-web: signed-in compare needs ${EMAIL_FILE} and ${PASS_FILE}; dist stamps were printed above" >&2
fi
