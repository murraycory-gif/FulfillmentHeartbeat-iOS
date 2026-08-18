#!/bin/sh
# Pull FulfillmentHeartbeat updates without wiping Xcode signing / your Apple team.
set -eu
cd "$(dirname "$0")"

PBX="FulfillmentHeartbeat.xcodeproj/project.pbxproj"
TEAM=""
if [ -f "$PBX" ]; then
  TEAM=$(awk -F'= |;' '/DEVELOPMENT_TEAM/ { gsub(/^[ \t"]+|[ \t"]+$/, "", $2); if ($2 != "") { print $2; exit } }' "$PBX")
fi

git fetch origin
if ! git pull --rebase --autostash origin main; then
  echo "Pull hit a conflict. Your signing is still saved — send me the terminal output."
  exit 1
fi

if [ -n "${TEAM:-}" ] && [ "$TEAM" != '""' ]; then
  python3 - "$PBX" "$TEAM" <<'PY'
import pathlib, sys
path, team = pathlib.Path(sys.argv[1]), sys.argv[2]
text = path.read_text()
if 'DEVELOPMENT_TEAM' in text:
    import re
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

open FulfillmentHeartbeat.xcworkspace
