#!/bin/bash
# Orchestrator checks: unchanged files do not deploy, a cook failure does not
# deploy, and a touched workbook deploys again. Uses stub cook/deploy commands.
set -euo pipefail

# This test invokes cook-local.sh directly. Skip the real git fetch and the
# detached/behind refusal so CI can run on a checkout that is not the Mac.
# The LaunchAgent path does not set this variable.
export HEARTBEAT_SKIP_GIT_CHECK=1

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/icloud" "$WORK/out" "$WORK/markers" "$WORK/bin"
DAILY="$WORK/icloud/Heartbeat Daily Report.xlsx"
SCHED="$WORK/icloud/Schedule Review Week 32 - Summary.xlsx"
# Size floor is 1MB for the real ingest. The stub is selected via HEARTBEAT_INGEST_BIN.
dd if=/dev/zero of="$DAILY" bs=1024 count=1100 status=none
dd if=/dev/zero of="$SCHED" bs=1024 count=1100 status=none
# Make the files old enough to pass the settle window.
touch -d '1 hour ago' "$DAILY" "$SCHED" 2>/dev/null || touch -t 202601010000 "$DAILY" "$SCHED"

cat > "$WORK/bin/fake-ingest" << 'EOF'
#!/bin/bash
set -euo pipefail
sqlite="$2"
python3 - "$sqlite" << 'PY'
import json, sqlite3, sys, time
dest = sys.argv[1]
con = sqlite3.connect(dest)
con.execute("CREATE TABLE IF NOT EXISTS dash_chrome (id INTEGER PRIMARY KEY, json TEXT)")
stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
con.execute("DELETE FROM dash_chrome")
con.execute("INSERT INTO dash_chrome(id, json) VALUES (1, ?)", (json.dumps({"publishedAt": stamp}),))
con.commit()
PY
echo "stub cooked $sqlite"
EOF
cat > "$WORK/bin/fake-schedule" << 'EOF'
#!/bin/bash
set -euo pipefail
python3 - "$HEARTBEAT_SCHEDULE_SQLITE" << 'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute("CREATE TABLE IF NOT EXISTS schedule_store (store TEXT)")
con.execute("DELETE FROM schedule_store")
con.executemany("INSERT INTO schedule_store(store) VALUES (?)", [(str(i),) for i in range(3)])
con.commit()
PY
echo "stub schedule"
EOF
cat > "$WORK/bin/fake-deploy" << 'EOF'
#!/bin/bash
set -euo pipefail
echo deploy >> "$HEARTBEAT_DEPLOY_LOG"
EOF
chmod +x "$WORK/bin/fake-ingest" "$WORK/bin/fake-schedule" "$WORK/bin/fake-deploy"

export HEARTBEAT_ICLOUD_DIR="$WORK/icloud"
export HEARTBEAT_COOK_OUT="$WORK/out"
export HEARTBEAT_COOK_MARKERS="$WORK/markers"
export HEARTBEAT_SETTLE_SECONDS=0
export HEARTBEAT_INGEST_BIN="$WORK/bin/fake-ingest"
export HEARTBEAT_SCHEDULE_CMD="$WORK/bin/fake-schedule"
export HEARTBEAT_DEPLOY_CMD="$WORK/bin/fake-deploy"
export HEARTBEAT_DEPLOY_LOG="$WORK/deploys.log"
: > "$HEARTBEAT_DEPLOY_LOG"

bash "$ROOT/Tools/HeartbeatIngest/cook-local.sh"
test "$(wc -l < "$HEARTBEAT_DEPLOY_LOG" | tr -d ' ')" = "1"
first="$(python3 -c 'import json,sqlite3; print(json.loads(sqlite3.connect("'"$WORK/out/current.sqlite"'").execute("select json from dash_chrome").fetchone()[0])["publishedAt"])')"

bash "$ROOT/Tools/HeartbeatIngest/cook-local.sh"
test "$(wc -l < "$HEARTBEAT_DEPLOY_LOG" | tr -d ' ')" = "1"

# Cook failure must not deploy.
cat > "$WORK/bin/fake-ingest" << 'EOF'
#!/bin/bash
echo "stub ingest failed" >&2
exit 1
EOF
chmod +x "$WORK/bin/fake-ingest"
touch "$DAILY"
set +e
bash "$ROOT/Tools/HeartbeatIngest/cook-local.sh"
fail=$?
set -e
test "$fail" -ne 0
test "$(wc -l < "$HEARTBEAT_DEPLOY_LOG" | tr -d ' ')" = "1"

# A later successful save deploys a new publishedAt.
cat > "$WORK/bin/fake-ingest" << 'EOF'
#!/bin/bash
set -euo pipefail
python3 - "$2" << 'PY'
import json, sqlite3, sys, time
dest = sys.argv[1]
con = sqlite3.connect(dest)
con.execute("CREATE TABLE IF NOT EXISTS dash_chrome (id INTEGER PRIMARY KEY, json TEXT)")
stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
con.execute("DELETE FROM dash_chrome")
con.execute("INSERT INTO dash_chrome(id, json) VALUES (1, ?)", (json.dumps({"publishedAt": stamp}),))
con.commit()
PY
EOF
chmod +x "$WORK/bin/fake-ingest"
sleep 1
touch "$DAILY"
bash "$ROOT/Tools/HeartbeatIngest/cook-local.sh"
test "$(wc -l < "$HEARTBEAT_DEPLOY_LOG" | tr -d ' ')" = "2"
second="$(python3 -c 'import json,sqlite3; print(json.loads(sqlite3.connect("'"$WORK/out/current.sqlite"'").execute("select json from dash_chrome").fetchone()[0])["publishedAt"])')"
test "$first" != "$second"

# Wrong Pages project is refused before wrangler.
set +e
HEARTBEAT_PAGES_PROJECT=heartbeat-web bash "$ROOT/Tools/HeartbeatIngest/publish-web.sh" "$WORK/out/current.sqlite"
refuse=$?
set -e
test "$refuse" -ne 0

guard() {
  bash "$ROOT/Tools/HeartbeatIngest/cook-guard.sh" "$@"
}
expect_refuse() {
  set +e
  local out
  out="$(guard "$@" 2>/dev/null)"
  local status=$?
  set -e
  test "$status" -ne 0
  test "$out" = "refuse"
}
expect_refuse web/scripts/extract_web_pack.py
expect_refuse Tools/HeartbeatIngest/cook-local.sh
expect_refuse Tools/HeartbeatIngest/prepare-sources.sh
expect_refuse Tools/HeartbeatIngest/nested/file.sh
expect_refuse web/check_pack.mjs
expect_refuse web/functions/pack-store.js
test "$(guard)" = "cook"
review_out="$(guard Tools/HeartbeatIngest/publish-web.sh 2>"$WORK/review.err")"
test "$review_out" = "review"
grep -q "flagged for review" "$WORK/review.err"
expect_refuse web/scripts/extract_web_pack.py Tools/HeartbeatIngest/publish-web.sh
set +e
refuse_out="$(guard web/public/app.js 2>"$WORK/refuse.err")"
refuse_status=$?
set -e
test "$refuse_status" -ne 0
test "$refuse_out" = "refuse"
set +e
both="$(guard web/check_pack.mjs Tools/HeartbeatIngest/publish-web.sh web/functions/_middleware.js 2>"$WORK/both.err")"
both_status=$?
set -e
test "$both_status" -ne 0
test "$both" = "refuse"
guard_src="$(cat "$ROOT/Tools/HeartbeatIngest/cook-guard.sh")"
for needle in \
  "web/scripts/extract_web_pack.py" \
  "Tools/HeartbeatIngest/cook-local.sh" \
  "Tools/HeartbeatIngest/" \
  "web/check_pack.mjs" \
  "web/functions/pack-store.js" \
  "schemaVersion" \
  "cookSha" \
  "laborMarket" \
  "regionTables" \
  "summaries" \
  "companyTiles" \
  "filters.stores" \
  "flagged for review" \
  "refusing a dirty cook path"
do
  grep -q "$needle" <<<"$guard_src"
done

echo "cook-local orchestrator ok first=$first second=$second"
