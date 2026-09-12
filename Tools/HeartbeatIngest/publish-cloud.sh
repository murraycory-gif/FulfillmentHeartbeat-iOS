#!/bin/bash
# Company-first cloud publish. Testers get an under-limit pack LIVE
# before ~2300 seat uploads. Seats run in parallel with timeouts/retries.
#
# This Supabase project rejects objects ≳50MB (413 / TUS "Maximum size
# exceeded"). The cooked market pack is ~56MB after VACUUM. The company
# seat is ~21MB — publish that as root current.sqlite when the market
# file is over STORAGE_FILE_LIMIT_BYTES.
#
# Usage:
#   publish-cloud.sh company /tmp/current.sqlite
#   publish-cloud.sh seats /tmp/current.sqlite
#   publish-cloud.sh seat-one /tmp/packs/seat/district/03/current.sqlite
set -u
PROJECT="${PROJECT:-https://pcnjujfmlsklhrosxzlt.supabase.co}"
KEY="${KEY:-sb_publishable_T3Pzm01sMXCv2rQaCeP_Kg_4ao2M5zd}"
SEAT_JOBS="${SEAT_JOBS:-16}"
# 50,000,000 — TUS on this project 413s at ~50MB. 56MB market must not be sent.
STORAGE_FILE_LIMIT_BYTES="${STORAGE_FILE_LIMIT_BYTES:-50000000}"
# Thin company Command Center. 56MB market must never become the company seat.
COMPANY_SEAT_MAX_BYTES="${COMPANY_SEAT_MAX_BYTES:-28000000}"
MODE="${1:-}"
TARGET="${2:-}"
SELF="$(CDPATH= cd "$(dirname "$0")" && pwd)/$(basename "$0")"
RESULT_ROOT="${SEAT_RESULT_ROOT:-/tmp/heartbeat-seat-uploads}"

file_bytes() {
  wc -c < "$1" | tr -d ' '
}

loud_413() {
  local object="$1"
  local file="$2"
  local body="$3"
  local bytes
  bytes=$(file_bytes "$file")
  echo "COOK FAILED: 413 EntityTooLarge / TUS Maximum size exceeded." >&2
  echo "  object=$object bytes=$bytes limit=$STORAGE_FILE_LIMIT_BYTES" >&2
  echo "  current.sqlite was NOT replaced. Bucket timestamp is not a fresh cook." >&2
  echo "  Cory: Supabase Dashboard → Storage → Settings → Global file size limit → 60 MB or higher." >&2
  echo "  Until that is raised, Actions publishes packs/seat/company/all/current.sqlite as current.sqlite." >&2
  if [ -n "$body" ]; then
    echo "$body" >&2
  fi
}

upload_object() {
  local object="$1"
  local file="$2"
  local type="$3"
  local max_time="${4:-90}"
  local encoded out code attempt bytes
  if [ ! -f "$file" ]; then
    echo "upload $object missing $file" >&2
    return 1
  fi
  bytes=$(file_bytes "$file")
  if [ "$bytes" -gt "$STORAGE_FILE_LIMIT_BYTES" ]; then
    echo "upload $object refused locally: $bytes bytes > Storage limit $STORAGE_FILE_LIMIT_BYTES." >&2
    echo "Not sending this object — a 413 would bump updated_at and look like a fresh pack." >&2
    return 41
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
    if [ "$code" = "413" ]; then
      loud_413 "$object" "$file" "$(cat "$out" 2>/dev/null || true)"
      rm -f "$out"
      return 41
    fi
    if [ "$code" = "200" ] || [ "$code" = "201" ]; then
      rm -f "$out"
      echo "upload $object $code ($bytes bytes)"
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
    if [ "$code" = "413" ]; then
      loud_413 "$object" "$file" "$(cat "$out" 2>/dev/null || true)"
      rm -f "$out"
      return 41
    fi
    if [ "$code" = "200" ] || [ "$code" = "201" ]; then
      rm -f "$out"
      echo "upload $object $code ($bytes bytes)"
      return 0
    fi
    sleep $((attempt * 2))
  done
  echo "upload $object FAILED $code ($bytes bytes)" >&2
  cat "$out" >&2 || true
  rm -f "$out"
  return 1
}

must_upload() {
  if upload_object "$@"; then
    return 0
  fi
  local status=$?
  if [ "$status" -eq 41 ]; then
    echo "COOK FAILED: company publish hit Storage 413. Stale pack was not replaced." >&2
  fi
  exit 1
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
COMPANY_SEAT="$PACK_ROOT/seat/company/all/current.sqlite"
if [ ! -f "$SQLITE" ]; then
  echo "Missing $SQLITE" >&2
  exit 1
fi

if [ "$MODE" = "company" ]; then
  set -e
  MARKET_BYTES=$(file_bytes "$SQLITE")
  if [ "$MARKET_BYTES" -lt 50000 ]; then
    echo "Market pack too small ($MARKET_BYTES)"
    exit 1
  fi
  test -f "$PACK_ROOT/manifest.json"
  test -f "$COMPANY_SEAT"
  COMPANY_BYTES=$(file_bytes "$COMPANY_SEAT")
  if [ "$COMPANY_BYTES" -lt 1000000 ]; then
    echo "Company seat too small ($COMPANY_BYTES). Need packs/seat/company/all/current.sqlite >= 1MB."
    exit 1
  fi
  if [ "$COMPANY_BYTES" -gt "$COMPANY_SEAT_MAX_BYTES" ]; then
    echo "COOK FAILED: company seat is $COMPANY_BYTES bytes, over thin-seat cap $COMPANY_SEAT_MAX_BYTES." >&2
    echo "iPad Jetsams a ~56MB company seat. Recook a thin company pack (~21MB). Do not publish market as company." >&2
    exit 1
  fi
  if [ "$COMPANY_BYTES" -gt "$STORAGE_FILE_LIMIT_BYTES" ]; then
    echo "COOK FAILED: company seat is $COMPANY_BYTES bytes, over Storage limit $STORAGE_FILE_LIMIT_BYTES." >&2
    echo "Cory: Supabase Dashboard → Storage → Settings → Global file size limit → 60 MB or higher." >&2
    echo "Not uploading — a 413 would make the stale pack look fresh." >&2
    exit 1
  fi
  LIVE_FILE="$SQLITE"
  LIVE_KIND="market"
  if [ "$MARKET_BYTES" -gt "$STORAGE_FILE_LIMIT_BYTES" ]; then
    echo "Market pack $MARKET_BYTES bytes > Storage limit $STORAGE_FILE_LIMIT_BYTES."
    echo "Publishing company seat ($COMPANY_BYTES bytes) as current.sqlite + seat path."
    LIVE_FILE="$COMPANY_SEAT"
    LIVE_KIND="company-seat"
  fi
  # Seat path first so a later root 413 cannot be the only write.
  must_upload "packs/seat/company/all/current.sqlite" "$COMPANY_SEAT" application/octet-stream 180
  must_upload "current.sqlite" "$LIVE_FILE" application/octet-stream 300
  must_upload "packs/manifest.json" "$PACK_ROOT/manifest.json" application/json 60
  LIVE_BYTES=$(file_bytes "$LIVE_FILE")
  echo "LIVE current.sqlite ($LIVE_BYTES bytes, $LIVE_KIND) + packs/manifest.json + company seat."
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
