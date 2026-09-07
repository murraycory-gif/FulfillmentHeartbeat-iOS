# Known-good load

**HB-0828.159 / 1.0 (530)** is the build that loaded every scorecard correctly
from `Heartbeat Daily Report.xlsx` (Labor + Picker included).

Do not change the parse path for those sheets.

Speed after that build:
- If the on-device pack already has Labor and Picker, skip the splash and
  skip the workbook download.
- Show Who's looking as soon as rows are in memory. Dashboard caches fill
  right after.
