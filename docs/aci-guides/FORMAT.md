# ACI tester guide format

Use this layout for every new feature or TestFlight drop. Do not invent a new style.

## Locked header
- Wordmark exactly as in the app: **Fulfill** `#003DA5` + **ment** `#00A9E0`, gradient underline, heart mark, ECG pulse `#00A9E0`
- Right side: `ACI Test Users`
- Under that: `Version X.Y  ·  Build NNN  ·  HB-stamp`
- Pulse bar then navy bar under the header
- Footer: `Internal  ·  Albertsons Companies  ·  Fulfillment Heartbeat` + the same version string

## Page flow
1. What changed + how to update in TestFlight (Home Screen + TestFlight screenshots)
2. Reload the master file (Upload → Choose file / Reload → iCloud folder)
3. Select the workbook and wait for “Reading master workbook”
4. New feature screens (this drop: Pre-Sub OOS Items)

## Rules
- Letter, 4 pages unless the feature needs a fifth
- Helvetica body, navy section titles, numbered step badges
- Full-sentence wrap — never cut a line mid-word
- Tight spacing; screenshots sit under the step they explain
- Always print the current `BuildStamp` so testers can match the sidebar

This drop: Version 1.0 · Build 343 · HB-0827.72 — Sales ScoreCard + file reload.

Next drop draft: `NEXT-READOUT.md` (Build 352 · HB-0827.81).

## Generate
```bash
cd docs/aci-guides
python3 make_guide.py
```

Output: `Fulfillment-Heartbeat-ACI-Test-Users-Update-Guide.pdf`
Edit `make_guide.py` `BUILD` / `STEPS` / screenshot paths when the next drop ships.
