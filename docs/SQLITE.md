# Auto-pull (no Upload tap)

Users should not pick Excel inside the app after the pack exists.

## How data gets in

1. You export `Heartbeat Daily Report.xlsx` from Power BI.
2. Put that file in one of these places:
   - The linked iCloud file already chosen once on this iPad, **or**
   - Files → On My iPad → Heartbeat (app Documents). Name must include `Heartbeat`, `Daily Report`, or `Master`.
3. Open Heartbeat. If that file is newer than the last load, the app imports it and rewrites `heartbeat.sqlite`. Who’s looking is not asked again.
4. If the file did not change, the app only opens the database.

## What testers do

Open the app. Data is there. No Choose file.

Someone still has to drop the new xlsx into that folder or iCloud link when the day changes. That is outside the app.
