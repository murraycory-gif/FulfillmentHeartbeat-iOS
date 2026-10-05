#!/bin/bash
# Extract a cooked current.sqlite and deploy the website.
# Cloudflare Pages project is fulfillment-heartbeat-web and nothing else.
# Token comes from CLOUDFLARE_API_TOKEN or ~/.config/heartbeat/cloudflare-api-token.
# This script never prints the token. A failed check does not deploy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SQLITE="${1:-}"
PROJECT="fulfillment-heartbeat-web"

if [[ "${HEARTBEAT_PAGES_PROJECT:-$PROJECT}" != "$PROJECT" ]]; then
  echo "Refusing Pages project '${HEARTBEAT_PAGES_PROJECT}'. Only ${PROJECT} is allowed." >&2
  exit 1
fi
if [[ -z "$SQLITE" || ! -f "$SQLITE" ]]; then
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
python3 "$ROOT/web/scripts/extract_web_pack.py" "$SQLITE" "$WEB/public/data"

python3 - "$WEB/public/data" << 'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
home = json.loads((root / "home.json").read_text())
schedule = json.loads((root / "schedule.json").read_text())
published = str(home.get("publishedAt") or "")
if len(published) < 20 or published == "2026-09-30T18:23:22Z":
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

# The session cookie is signed with SESSION_SECRET. Create it once.
# A later deploy must not rotate it, or every saved login stops working.
SECRET_FILE="${HEARTBEAT_SESSION_SECRET_FILE:-$HOME/.config/heartbeat/session-secret}"
SECRET_LIST="$(npx wrangler pages secret list --project-name "$PROJECT" 2>/dev/null || true)"
if ! grep -q "SESSION_SECRET" <<<"$SECRET_LIST"; then
  if [[ ! -s "$SECRET_FILE" ]]; then
    mkdir -p "$(dirname "$SECRET_FILE")"
    umask 077
    openssl rand -base64 32 > "$SECRET_FILE"
  fi
  npx wrangler pages secret put SESSION_SECRET --project-name "$PROJECT" < "$SECRET_FILE"
fi

npx wrangler pages deploy dist \
  --project-name "$PROJECT" \
  --branch main \
  --commit-dirty=true
