#!/bin/bash
# Company-first publish. Testers get current.sqlite LIVE before any seat
# uploads. Main cook thins in place, so /tmp/current.sqlite IS the company
# seat. A separate packs/seat tree is optional (continue if absent).
#
# Object keys match what the app downloads:
#   current.sqlite
#   packs/seat/company/all/current.sqlite
#   packs/manifest.json          (only when the cook wrote one)
#
# R2 is the primary host. After those two company objects land on R2, the
# same bytes are upserted to Supabase Storage (tip 468 still reads that
# bucket). Seat path first, then root — same order as the old Supabase cook.
#
# Required env for R2 (GitHub secrets or a local export — do not hardcode):
#   R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ACCOUNT_ID R2_BUCKET
# Supabase mirror key (first match in scripts/publish-supabase.sh):
#   SUPABASE_SERVICE_ROLE_KEY, SUPABASE_KEY, SUPABASE_ANON_KEY,
#   or HEARTBEAT_SUPABASE_PUBLISHABLE_KEY
#
# Usage:
#   publish-cloud.sh company /tmp/current.sqlite
#   publish-cloud.sh seats /tmp/current.sqlite
#   publish-cloud.sh seat-one /tmp/packs/seat/district/03/current.sqlite
#   publish-cloud.sh mirror-supabase /tmp/current.sqlite
set -u
SEAT_JOBS="${SEAT_JOBS:-16}"
# Same cap as the cook thin gate. A ~56MB market must not become LIVE.
COMPANY_SEAT_MAX_BYTES="${COMPANY_SEAT_MAX_BYTES:-40000000}"
MODE="${1:-}"
TARGET="${2:-}"
SELF="$(CDPATH= cd "$(dirname "$0")" && pwd)/$(basename "$0")"
RESULT_ROOT="${SEAT_RESULT_ROOT:-/tmp/heartbeat-seat-uploads}"

file_bytes() {
  wc -c < "$1" | tr -d ' '
}

require_r2() {
  local missing="" var val
  for var in R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ACCOUNT_ID R2_BUCKET; do
    eval "val=\${$var:-}"
    if [ -z "$val" ]; then
      missing="$missing $var"
    fi
  done
  if [ -n "$missing" ]; then
    echo "Missing R2 env:$missing" >&2
    echo "Set GitHub secrets R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ACCOUNT_ID R2_BUCKET." >&2
    exit 1
  fi
  if ! command -v aws >/dev/null 2>&1; then
    echo "aws CLI is required to publish to R2." >&2
    exit 1
  fi
  export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
  export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
  export AWS_EC2_METADATA_DISABLED=true
  export AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED
  export AWS_RESPONSE_CHECKSUM_VALIDATION=WHEN_REQUIRED
  R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
}

upload_object() {
  local object="$1"
  local file="$2"
  local type="$3"
  local bytes attempt
  if [ ! -f "$file" ]; then
    echo "upload $object missing $file" >&2
    return 1
  fi
  require_r2
  bytes=$(file_bytes "$file")
  for attempt in 1 2 3; do
    if aws s3 cp "$file" "s3://${R2_BUCKET}/${object}" \
      --endpoint-url "$R2_ENDPOINT" \
      --content-type "$type" \
      --cache-control "public, max-age=60"; then
      echo "upload $object ok ($bytes bytes)"
      return 0
    fi
    sleep $((attempt * 2))
  done
  echo "upload $object FAILED ($bytes bytes)" >&2
  return 1
}

must_upload() {
  if upload_object "$@"; then
    return 0
  fi
  echo "COOK FAILED: company publish did not land on R2. Stale pack was not replaced." >&2
  exit 1
}

supabase_publish() {
  local script
  script="$(CDPATH= cd "$(dirname "$0")/../.." && pwd)/scripts/publish-supabase.sh"
  if [ ! -f "$script" ]; then
    echo "Missing $script" >&2
    exit 1
  fi
  chmod +x "$script"
  "$script" "$@"
}

# Same thin file the R2 company step just published. Seat key first, then root.
mirror_company_supabase() {
  local seat_file="$1"
  local live_file="$2"
  echo "Mirroring company LIVE onto Supabase (same bytes as R2)."
  if ! supabase_publish "$seat_file" "packs/seat/company/all/current.sqlite" application/octet-stream; then
    echo "COOK FAILED: R2 company seat landed, but Supabase packs/seat/company/all/current.sqlite did not." >&2
    echo "Tip 468 still reads Supabase. Set SUPABASE_SERVICE_ROLE_KEY if the upload key was rejected." >&2
    exit 1
  fi
  if ! supabase_publish "$live_file" "current.sqlite" application/octet-stream; then
    echo "COOK FAILED: R2 current.sqlite landed, but Supabase root current.sqlite did not." >&2
    echo "Tip 468 still reads Supabase. Set SUPABASE_SERVICE_ROLE_KEY if the upload key was rejected." >&2
    exit 1
  fi
  echo "Supabase current.sqlite matches this cook. Root and company seat keys."
  echo "Removing facts.json so the Sep 12 object cannot stay in heartbeat-packs."
  if ! supabase_publish --delete facts.json; then
    echo "COOK FAILED: facts.json is still in heartbeat-packs." >&2
    echo "Delete must return 200, 204, or 404. Refusing to leave the stale object." >&2
    exit 1
  fi
}

mark_seat() {
  local status="$1"
  local object="$2"
  local stamp
  stamp=$(python3 -c "import hashlib,sys; print(hashlib.sha1(sys.argv[1].encode()).hexdigest())" "$object")
  mkdir -p "$RESULT_ROOT/$status"
  : > "$RESULT_ROOT/$status/$stamp"
}

if [ "$MODE" = "mirror-supabase" ]; then
  file="$TARGET"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    echo "Usage: publish-cloud.sh mirror-supabase /tmp/current.sqlite" >&2
    exit 2
  fi
  MIRROR_BYTES=$(file_bytes "$file")
  if [ "$MIRROR_BYTES" -lt 1000000 ]; then
    echo "Refusing Supabase mirror of $file ($MIRROR_BYTES bytes). Need >= 1MB." >&2
    exit 1
  fi
  if [ "$MIRROR_BYTES" -gt "$COMPANY_SEAT_MAX_BYTES" ]; then
    echo "Refusing Supabase mirror of $file ($MIRROR_BYTES bytes), over thin-seat cap $COMPANY_SEAT_MAX_BYTES." >&2
    exit 1
  fi
  mirror_company_supabase "$file" "$file"
  exit 0
fi

if [ "$MODE" = "seat-one" ]; then
  file="$TARGET"
  object="${file#/tmp/}"
  if upload_object "$object" "$file" application/octet-stream; then
    mark_seat ok "$object"
    exit 0
  fi
  mark_seat fail "$object"
  exit 1
fi

if [ -z "$MODE" ] || [ -z "$TARGET" ]; then
  echo "Usage: publish-cloud.sh company|seats|mirror-supabase /tmp/current.sqlite" >&2
  exit 2
fi

SQLITE="$TARGET"
PACK_ROOT="$(cd "$(dirname "$SQLITE")" && pwd)/packs"
COMPANY_SEAT="$PACK_ROOT/seat/company/all/current.sqlite"

if [ "$MODE" = "company" ]; then
  set -e
  if [ ! -f "$SQLITE" ]; then
    echo "Missing $SQLITE" >&2
    exit 1
  fi
  MARKET_BYTES=$(file_bytes "$SQLITE")
  if [ "$MARKET_BYTES" -lt 1000000 ]; then
    echo "Market pack too small ($MARKET_BYTES). Need current.sqlite >= 1MB." >&2
    exit 1
  fi

  LIVE_FILE="$SQLITE"
  LIVE_KIND="thin-company"
  SEAT_FILE="$SQLITE"
  if [ -f "$COMPANY_SEAT" ]; then
    COMPANY_BYTES=$(file_bytes "$COMPANY_SEAT")
    if [ "$COMPANY_BYTES" -lt 1000000 ]; then
      echo "Company seat too small ($COMPANY_BYTES). Need packs/seat/company/all/current.sqlite >= 1MB." >&2
      exit 1
    fi
    if [ "$COMPANY_BYTES" -gt "$COMPANY_SEAT_MAX_BYTES" ]; then
      echo "COOK FAILED: company seat is $COMPANY_BYTES bytes, over thin-seat cap $COMPANY_SEAT_MAX_BYTES." >&2
      echo "iPad Jetsams a fat company seat. Recook a thin company pack. Do not publish market as company." >&2
      exit 1
    fi
    SEAT_FILE="$COMPANY_SEAT"
    if [ "$MARKET_BYTES" -gt "$COMPANY_SEAT_MAX_BYTES" ]; then
      echo "Market pack $MARKET_BYTES bytes > thin-seat cap $COMPANY_SEAT_MAX_BYTES."
      echo "Publishing company seat ($COMPANY_BYTES bytes) as current.sqlite + seat path."
      LIVE_FILE="$COMPANY_SEAT"
      LIVE_KIND="company-seat"
    else
      LIVE_KIND="market"
    fi
  elif [ "$MARKET_BYTES" -gt "$COMPANY_SEAT_MAX_BYTES" ]; then
    echo "COOK FAILED: current.sqlite is $MARKET_BYTES bytes, over thin-seat cap $COMPANY_SEAT_MAX_BYTES." >&2
    echo "No packs/seat/company/all/current.sqlite to publish instead. Refusing the fat pack." >&2
    exit 1
  fi

  LIVE_BYTES=$(file_bytes "$LIVE_FILE")
  if [ "$LIVE_BYTES" -gt "$COMPANY_SEAT_MAX_BYTES" ]; then
    echo "COOK FAILED: LIVE pack is $LIVE_BYTES bytes, over thin-seat cap $COMPANY_SEAT_MAX_BYTES." >&2
    exit 1
  fi

  require_r2
  must_upload "packs/seat/company/all/current.sqlite" "$SEAT_FILE" application/octet-stream
  must_upload "current.sqlite" "$LIVE_FILE" application/octet-stream
  if [ -f "$PACK_ROOT/manifest.json" ]; then
    must_upload "packs/manifest.json" "$PACK_ROOT/manifest.json" application/json
  else
    echo "No packs/manifest.json. Company LIVE does not require a seat plane."
  fi
  echo "LIVE current.sqlite ($LIVE_BYTES bytes, $LIVE_KIND) on R2."
  echo "Download: https://pub-eafb309f53464d98902d12ac107f0f1e.r2.dev/current.sqlite"
  mirror_company_supabase "$SEAT_FILE" "$LIVE_FILE"
  echo "Testers can force-close Heartbeat now. Seat packs upload next when present."
  exit 0
fi

if [ "$MODE" != "seats" ]; then
  echo "Unknown mode $MODE" >&2
  exit 2
fi

if [ ! -d "$PACK_ROOT/seat" ]; then
  echo "No packs/seat directory. Company LIVE is the pack. Skipping seat publish."
  exit 0
fi

LOCAL_N=$(find "$PACK_ROOT/seat" -name current.sqlite ! -path '*/company/*' | wc -l | tr -d ' ')
if [ "$LOCAL_N" -lt 1 ]; then
  echo "No district/store/OM seats on this cook. Company LIVE is the pack."
  exit 0
fi

require_r2
if aws s3 sync "$PACK_ROOT/seat" "s3://${R2_BUCKET}/packs/seat" \
  --endpoint-url "$R2_ENDPOINT" \
  --cache-control "public, max-age=60"; then
  echo "Seat sync ok. local_non_company=$LOCAL_N"
  echo "Seat uploads ok=$LOCAL_N fail=0 jobs=sync"
  exit 0
fi

echo "aws s3 sync failed — falling back to parallel per-object uploads."
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
