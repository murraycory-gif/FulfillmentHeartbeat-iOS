#!/bin/sh
# Recover a broken Xcode project and install the latest Heartbeat on the iPad.
set -eu
cd "$(dirname "$0")"

echo "Quit Xcode completely (Cmd+Q) if it is still open."
killall Xcode 2>/dev/null || true
sleep 1

PBX="FulfillmentHeartbeat.xcodeproj/project.pbxproj"
TEAM=""
if [ -f "$PBX" ]; then
  TEAM=$(awk -F'= |;' '/DEVELOPMENT_TEAM/ { gsub(/^[ \t"]+|[ \t"]+$/, "", $2); if ($2 != "" && $2 != "\"\"" ) { print $2; exit } }' "$PBX")
fi

git fetch origin
git rebase --abort >/dev/null 2>&1 || true
git merge --abort >/dev/null 2>&1 || true
git reset --hard origin/main
git clean -fd -e .DS_Store >/dev/null 2>&1 || true

if [ -n "${TEAM:-}" ]; then
  python3 - "$PBX" "$TEAM" <<'PY'
import pathlib, sys, re
path, team = pathlib.Path(sys.argv[1]), sys.argv[2]
text = path.read_text()
if 'DEVELOPMENT_TEAM' in text:
    text = re.sub(r'DEVELOPMENT_TEAM = [^;]+;', f'DEVELOPMENT_TEAM = {team};', text)
else:
    text = text.replace(
        'CODE_SIGN_STYLE = Automatic;',
        f'CODE_SIGN_STYLE = Automatic;\n\t\t\t\tDEVELOPMENT_TEAM = {team};',
        2,
    )
path.write_text(text)
print(f"Kept your Apple team: {team}")
PY
fi

echo ""
echo "Source stamp:"
grep 'static let id' FulfillmentHeartbeat/BuildStamp.swift || true

UDID="${DEVICE_UDID:-00008103-000960E61E30801E}"
DEVICE_UDID="$UDID" ./install-ipad.sh
