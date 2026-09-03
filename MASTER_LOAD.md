# Master load — bookmark for the shared workbook

Use this when you build the weekly master sheet. Heartbeat maps **tab names** (not the Excel file name) to scorecards.

**Suggested file name (keep this name every week):** `Heartbeat Master.xlsx`

Put it in the same iCloud / OneDrive folder. After you Choose file once, tap **Reload shared file** — no picker.

Overwrite that file each week. Do not rename it or the link breaks.

---

## Tab names (exact)

Create one sheet per KPI. Use these tab names:

| # | Tab name | Scorecard |
|---|---|---|
| 1 | `Sales` | Sales ScoreCard |
| 2 | `Lost Revenue` | Loss Revenue |
| 3 | `MI` | Missing Items |
| 4 | `5 Star` | 5 Star Metrics |
| 5 | `Pre-Sub OOS` | Pre-Sub OOS |
| 6 | `Pre-Sub OOS Item` | Item rows on the Pre-Sub OOS page |
| 7 | `Pick Path` | Pick Path Compliance |
| 8 | `Path Picker` | Pick Path Compliance Picker |
| 9 | `Aisle Mapper` | Aisle Mapper dates on Pick Path |
| 10 | `Prep Not Ready` | Prep Not Ready |
| 11 | `Dynacap` | Dynacap Setting |
| 12 | `Schedule Quality` | Schedule Quality |
| 13 | `PPH` | PPH Pure Picks Per Hour |
| 14 | `Labor` | Labor |
| 15 | `Picker ScoreCard` | Picker ScoreCard |

Paste the matching Power BI export onto each tab. Headers can stay as the export — we already map those.

---

## Also accepted (if a tab name is close)

- Lost Revenue / Loss Revenue
- MI / Missing Items / Missing Item / Aisle Tag
- 5 Star / Five Star / Star Rating
- Pre-Sub OOS / Pre Sub / Pre Substitution OOS
- Pre-Sub OOS Item / Pre Sub OOS Item / items by Store
- Pick Path / Path Compliance
- Path Picker / Pick Path Picker / Pick Path Employee
- Aisle Mapper / Aisle Sequence
- Prep / Prep Not Ready
- Dynacap / Capacity
- Schedule / Schedule Quality
- PPH / Pure Pick
- Labor
- Picker ScoreCard / Picker Score / Shopper

If a tab is still named `Sheet1`, we try to map it from the column headers. Named tabs are safer.

---

## Weekly flow

1. Refresh each Power BI export into the matching tab (or copy/paste).
2. Save `Heartbeat Master.xlsx` in the same shared folder.
3. On the iPad: **Upload → Reload shared file**.
