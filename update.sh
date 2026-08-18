#!/bin/sh
# Pull FulfillmentHeartbeat updates without wiping Xcode signing / your Apple team.
set -eu
cd "$(dirname "$0")"

PBX="FulfillmentHeartbeat.xcodeproj/project.pbxproj"
TEAM=""
if [ -f "$PBX" ]; then
  TEAM=$(awk -F'= |;' '/DEVELOPMENT_TEAM/ { gsub(/^[ \t"]+|[ \t"]+$/, "", $2); if ($2 != "" && $2 != "\"\"" ) { print $2; exit } }' "$PBX")
fi

git fetch origin
git rebase --abort >/dev/null 2>&1 || true
git merge --abort >/dev/null 2>&1 || true
git cherry-pick --abort >/dev/null 2>&1 || true

# A half-merged project.pbxproj makes Xcode say "Failed to load container".
if git diff --name-only --diff-filter=U | grep -q . || grep -q '<<<<<<<' "$PBX" 2>/dev/null; then
  echo "Local project file was stuck. Resetting to the latest app..."
  git reset --hard origin/main
elif ! git pull --rebase --autostash origin main; then
  echo "Pull failed. Resetting to the latest app and keeping your signing..."
  git reset --hard origin/main
fi

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

rm -rf \
  FulfillmentHeartbeat.xcodeproj/xcuserdata \
  FulfillmentHeartbeat.xcodeproj/project.xcworkspace/xcuserdata \
  FulfillmentHeartbeat.xcworkspace/xcuserdata \
  ~/Library/Developer/Xcode/DerivedData/FulfillmentHeartbeat-* 2>/dev/null || true

echo ""
echo "Quit Xcode first if it is still open."
echo "Opening FulfillmentHeartbeat.xcworkspace (not the .xcodeproj)..."
open "$PWD/FulfillmentHeartbeat.xcworkspace"
