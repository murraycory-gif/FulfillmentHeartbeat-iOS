#!/bin/sh
# Upload one object to the Heartbeat Supabase Storage bucket.
# Overwrites in place the way cooks did before company LIVE moved to R2:
# POST with x-upsert, then PUT with x-upsert if the first call is not 200/201.
#
# Required env is an upload key. First match wins (do not invent a value):
#   SUPABASE_SERVICE_ROLE_KEY   GitHub secret. Use this if anon upsert is revoked.
#   SUPABASE_KEY                GitHub secret or an explicit export.
#   SUPABASE_ANON_KEY           GitHub secret.
#   HEARTBEAT_SUPABASE_PUBLISHABLE_KEY
#                               Same publishable key the cook already uses to
#                               read Heartbeat Daily Report.xlsx. The workflow
#                               passes it. It is not a new credential.
#
# Optional:
#   SUPABASE_URL                Defaults to the Heartbeat project.
#   SUPABASE_BUCKET             Defaults to heartbeat-packs.
#
# Usage: ./scripts/publish-supabase.sh <local-file> <object-key> [content-type]
set -eu

FILE="${1:-}"
OBJECT="${2:-}"
TYPE="${3:-application/octet-stream}"
PROJECT="${SUPABASE_URL:-https://pcnjujfmlsklhrosxzlt.supabase.co}"
BUCKET="${SUPABASE_BUCKET:-heartbeat-packs}"
PROJECT="${PROJECT%/}"
# Same cap as the cook thin gate. A fat market pack must not land here.
MAX_BYTES="${COMPANY_SEAT_MAX_BYTES:-40000000}"

if [ -z "$FILE" ] || [ -z "$OBJECT" ] || [ ! -f "$FILE" ]; then
  echo "Usage: $0 <local-file> <object-key> [content-type]" >&2
  exit 1
fi

KEY=""
if [ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]; then
  KEY="$SUPABASE_SERVICE_ROLE_KEY"
elif [ -n "${SUPABASE_KEY:-}" ]; then
  KEY="$SUPABASE_KEY"
elif [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  KEY="$SUPABASE_ANON_KEY"
elif [ -n "${HEARTBEAT_SUPABASE_PUBLISHABLE_KEY:-}" ]; then
  KEY="$HEARTBEAT_SUPABASE_PUBLISHABLE_KEY"
fi
if [ -z "$KEY" ]; then
  echo "Missing Supabase upload key." >&2
  echo "Set GitHub secret SUPABASE_SERVICE_ROLE_KEY (preferred if anon upsert returns 401/403)." >&2
  echo "Otherwise set SUPABASE_KEY or SUPABASE_ANON_KEY." >&2
  echo "The cook workflow passes HEARTBEAT_SUPABASE_PUBLISHABLE_KEY — the publishable key it already uses to read the workbook." >&2
  exit 1
fi

BYTES=$(wc -c < "$FILE" | tr -d ' ')
if [ "$BYTES" -gt "$MAX_BYTES" ]; then
  echo "upload $OBJECT refused locally: $BYTES bytes > thin-seat cap $MAX_BYTES." >&2
  echo "Not sending this object — a 413 would bump updated_at and look like a fresh pack." >&2
  exit 1
fi

ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe='/'))" "$OBJECT")
URL="$PROJECT/storage/v1/object/$BUCKET/$ENCODED"
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

post_object() {
  method="$1"
  curl -sS -o "$OUT" -w "%{http_code}" \
    --connect-timeout 15 --max-time 300 \
    -X "$method" \
    -H "Authorization: Bearer $KEY" -H "apikey: $KEY" \
    -H "Content-Type: $TYPE" \
    -H "x-upsert: true" \
    --data-binary @"$FILE" \
    "$URL" || echo "000"
}

CODE="000"
attempt=1
while [ "$attempt" -le 3 ]; do
  CODE=$(post_object POST)
  if [ "$CODE" = "200" ] || [ "$CODE" = "201" ]; then
    break
  fi
  if [ "$CODE" = "413" ]; then
    echo "COOK FAILED: 413 EntityTooLarge uploading $OBJECT ($BYTES bytes)." >&2
    cat "$OUT" >&2 || true
    exit 1
  fi
  CODE=$(post_object PUT)
  if [ "$CODE" = "200" ] || [ "$CODE" = "201" ]; then
    break
  fi
  if [ "$CODE" = "413" ]; then
    echo "COOK FAILED: 413 EntityTooLarge uploading $OBJECT ($BYTES bytes)." >&2
    cat "$OUT" >&2 || true
    exit 1
  fi
  sleep $((attempt * 2))
  attempt=$((attempt + 1))
done

if [ "$CODE" != "200" ] && [ "$CODE" != "201" ]; then
  echo "upload $OBJECT FAILED $CODE ($BYTES bytes)" >&2
  cat "$OUT" >&2 || true
  if [ "$CODE" = "401" ] || [ "$CODE" = "403" ]; then
    echo "Supabase rejected the upload key. Set GitHub secret SUPABASE_SERVICE_ROLE_KEY and rerun the cook." >&2
  fi
  exit 1
fi

# Public HEAD must show the same byte count the cook just wrote.
# Fall back to a 1-byte range, then the list API, if HEAD omits the length.
PUBLIC="$PROJECT/storage/v1/object/public/$BUCKET/$ENCODED"
header_value() {
  awk -v name="$1" 'BEGIN { name=tolower(name) }
    { line=tolower($0) }
    index(line, name ":")==1 {
      sub(/^[^:]+:[ \t]*/, "", $0)
      gsub(/\r/, "", $0)
      print
      exit
    }'
}

HEAD_HEADERS=$(curl -sS -I -L --connect-timeout 15 --max-time 30 \
  -H "Authorization: Bearer $KEY" -H "apikey: $KEY" \
  "$PUBLIC" || true)
REMOTE_BYTES=$(printf '%s\n' "$HEAD_HEADERS" | header_value "content-length")
if [ -z "$REMOTE_BYTES" ]; then
  RANGE_HEADERS=$(curl -sS -D - -o /dev/null -L --connect-timeout 15 --max-time 30 \
    -H "Authorization: Bearer $KEY" -H "apikey: $KEY" \
    -H "Range: bytes=0-0" \
    "$PUBLIC" || true)
  RANGE=$(printf '%s\n' "$RANGE_HEADERS" | header_value "content-range")
  REMOTE_BYTES="${RANGE##*/}"
  case "$REMOTE_BYTES" in
    ""|*\*) REMOTE_BYTES="" ;;
  esac
fi
if [ -z "$REMOTE_BYTES" ]; then
  # dirname of "current.sqlite" is "."; list the bucket root for that key.
  case "$OBJECT" in
    */*) LIST_PREFIX="$(dirname "$OBJECT")/" ;;
    *) LIST_PREFIX="" ;;
  esac
  LIST_BODY=$(python3 -c "import json,sys; print(json.dumps({'prefix': sys.argv[1], 'limit': 50}))" "$LIST_PREFIX")
  LIST_JSON=$(curl -sS --connect-timeout 15 --max-time 30 \
    -X POST \
    -H "Authorization: Bearer $KEY" -H "apikey: $KEY" \
    -H "Content-Type: application/json" \
    -d "$LIST_BODY" \
    "$PROJECT/storage/v1/object/list/$BUCKET" || true)
  LEAF=$(basename "$OBJECT")
  REMOTE_BYTES=$(printf '%s' "$LIST_JSON" | python3 -c "
import json,sys
leaf=sys.argv[1]
try:
    rows=json.load(sys.stdin)
except Exception:
    rows=[]
if not isinstance(rows, list):
    rows=[]
for row in rows:
    if row.get('name')!=leaf:
        continue
    meta=row.get('metadata') or {}
    for key in ('size','contentLength'):
        if meta.get(key) is not None:
            print(int(meta[key]))
            raise SystemExit
" "$LEAF" || true)
fi
if [ -z "$REMOTE_BYTES" ]; then
  echo "Supabase $OBJECT did not report a size after upload $CODE." >&2
  exit 1
fi
if [ "$REMOTE_BYTES" != "$BYTES" ]; then
  echo "Supabase $OBJECT is $REMOTE_BYTES bytes after upload; local file is $BYTES. Mirror did not land." >&2
  exit 1
fi

echo "upload $OBJECT $CODE ($BYTES bytes) supabase"
