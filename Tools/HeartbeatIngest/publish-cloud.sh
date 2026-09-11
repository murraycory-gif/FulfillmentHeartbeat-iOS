#!/bin/bash
# Company-first cloud publish. Testers get current.sqlite + manifest LIVE
# before ~2300 seat uploads. Seats run in parallel with timeouts/retries.
# Usage:
#   publish-cloud.sh company /tmp/current.sqlite
#   publish-cloud.sh seats /tmp/current.sqlite
#   publish-cloud.sh seat-one /tmp/packs/seat/district/03/current.sqlite
set -u
PROJECT="${PROJECT:-https://pcnjujfmlsklhrosxzlt.supabase.co}"
KEY="${KEY:-sb_publishable_T3Pzm01sMXCv2rQaCeP_Kg_4ao2M5zd}"
SEAT_JOBS="${SEAT_JOBS:-16}"
MODE="${1:-}"
TARGET="${2:-}"
SELF="$(CDPATH= cd "$(dirname "$0")" && pwd)/$(basename "$0")"
RESULT_ROOT="${SEAT_RESULT_ROOT:-/tmp/heartbeat-seat-uploads}"

upload_object() {
  local object="$1"
  local file="$2"
  local type="$3"
  local max_time="${4:-90}"
  local encoded out code attempt
  if [ ! -f "$file" ]; then
    echo "upload $object missing $file" >&2
    return 1
  fi
  encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe='/'))" "$object")
  out=$(mktemp)
  code="000"
  for attempt in 1 2 3; do
    code=$(curl -sS -o "$out" -w "%{http_code}" \
      --connect-timeout 15 --max-time "$max_time" \
      -X POST \
      -H "Authorization: Bearer $KEY" -H "apikey: $KEY" \
      -H "Content-Type: $type" \
      -H "x-upsert: true" \
      --data-binary @"$file" \
      "$PROJECT/storage/v1/object/heartbeat-packs/$encoded" || echo "000")
    if [ "$code" = "200" ] || [ "$code" = "201" ]; then
      rm -f "$out"
      echo "upload $object $code"
      return 0
    fi
    code=$(curl -sS -o "$out" -w "%{http_code}" \
      --connect-timeout 15 --max-time "$max_time" \
      -X PUT \
      -H "Authorization: Bearer $KEY" -H "apikey: $KEY" \
      -H "Content-Type: $type" \
      -H "x-upsert: true" \
      --data-binary @"$file" \
      "$PROJECT/storage/v1/object/heartbeat-packs/$encoded" || echo "000")
    if [ "$code" = "200" ] || [ "$code" = "201" ]; then
      rm -f "$out"
      echo "upload $object $code"
      return 0
    fi
    sleep $((attempt * 2))
  done
  echo "upload $object FAILED $code" >&2
  cat "$out" >&2 || true
  rm -f "$out"
  return 1
}

mark_seat() {
  local status="$1"
  local object="$2"
  local stamp
  stamp=$(python3 -c "import hashlib,sys; print(hashlib.sha1(sys.argv[1].encode()).hexdigest())" "$object")
  mkdir -p "$RESULT_ROOT/$status"
  : > "$RESULT_ROOT/$status/$stamp"
}

if [ "$MODE" = "seat-one" ]; then
  file="$TARGET"
  object="${file#/tmp/}"
  if upload_object "$object" "$file" application/octet-stream 90; then
    mark_seat ok "$object"
    exit 0
  fi
  mark_seat fail "$object"
  exit 1
fi

if [ -z "$MODE" ] || [ -z "$TARGET" ]; then
  echo "Usage: publish-cloud.sh company|seats /tmp/current.sqlite" >&2
  exit 2
fi

SQLITE="$TARGET"
PACK_ROOT="$(cd "$(dirname "$SQLITE")" && pwd)/packs"
if [ ! -f "$SQLITE" ]; then
  echo "Missing $SQLITE" >&2
  exit 1
fi

if [ "$MODE" = "company" ]; then
  set -e
  BYTES=$(wc -c < "$SQLITE" | tr -d ' ')
  if [ "$BYTES" -lt 50000 ]; then
    echo "Pack too small ($BYTES)"
    exit 1
  fi
  test -f "$PACK_ROOT/manifest.json"
  upload_object "current.sqlite" "$SQLITE" application/octet-stream 300
  upload_object "packs/manifest.json" "$PACK_ROOT/manifest.json" application/json 60
  if [ -f "$PACK_ROOT/seat/company/all/current.sqlite" ]; then
    upload_object "packs/seat/company/all/current.sqlite" \
      "$PACK_ROOT/seat/company/all/current.sqlite" application/octet-stream 180
  fi
  echo "LIVE current.sqlite ($BYTES bytes) + packs/manifest.json + company seat."
  echo "Testers can force-close Heartbeat now. Seat packs upload in parallel next."
  exit 0
fi

if [ "$MODE" != "seats" ]; then
  echo "Unknown mode $MODE" >&2
  exit 2
fi

rm -rf "$RESULT_ROOT"
mkdir -p "$RESULT_ROOT/ok" "$RESULT_ROOT/fail"
set +e
find "$PACK_ROOT/seat" -name current.sqlite ! -path '*/company/*' \
  | sort \
  | xargs -P "$SEAT_JOBS" -n 1 "$SELF" seat-one
set -e
OK_N=$(find "$RESULT_ROOT/ok" -type f 2>/dev/null | wc -l | tr -d ' ')
FAIL_N=$(find "$RESULT_ROOT/fail" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "Seat uploads ok=$OK_N fail=$FAIL_N jobs=$SEAT_JOBS"
if [ "$OK_N" -lt 1 ]; then
  echo "No district/store/OM seats uploaded. Company is still LIVE."
fi
if [ "$FAIL_N" -gt 0 ]; then
  echo "Some seats failed and can retry on the next cook. Company stays LIVE."
fi
exit 0
