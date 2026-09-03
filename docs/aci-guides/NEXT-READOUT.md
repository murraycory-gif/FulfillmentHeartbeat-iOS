# Next ACI technical readout — draft

Use this list when the next TestFlight guide is generated. Same locked format as `FORMAT.md`.

**Target stamp:** Version 1.0 · Build 352 · HB-0827.81  
**Last published guide:** Version 1.0 · Build 343 · HB-0827.72

---

## What changed since Build 343

### Sales ScoreCard
- Dashboard callouts stay **Sales first, Loss Revenue second** on every role and filter.
- Company-wide Sales headline uses the export **Total Sales $** week column (sheet total $37,758,748 on the Week 27 file). Store 239 is no longer dropped from that sum.
- Health bands: Sales YoY over 0% Healthy, flat Watch, below 0% At Risk.
- Store table label is **store | district | market** (example `3607 | A9 | Mid-Atlantic`).
- Stores that only exist on the Sales tab inherit market from other stores in the same district.
- Store and market tables use fixed column widths so names and dollars stay on one line. Scroll sideways if needed.
- Unassigned / empty market rows stay hidden.
- Master Excel tab name: **Sales**. Individual upload card uses the Power BI Sales export.

### Share email
- Dashboard recap includes Healthy / Watch / At Risk **store counts**, not empty chips.
- Markets (or districts / stores, matching the current filter) are **expanded** under each callout.
- Flag tiles stack name, value, count, and badge so numbers do not wrap.
- Same HTML on iPad and iPhone. Apple Mail only.

### Navigation
- Tiny circle buttons replaced with labeled pills on every page:
  - **Menu** — white pill, opens the sidebar
  - **Back** — blue pill, returns to the dashboard
- 44pt tap height so Menu and Back are not hit by mistake.

### Reliability
- `salesActionFlags` compile fix (healthy count).
- Sales parser reads the sheet Total row as company grain for the unfiltered headline.

---

## Guide page plan (when testers need the PDF)

1. What changed + TestFlight Update to Build 352 / HB-0827.81  
2. Reload master file (tab **Sales** must be present)  
3. Dashboard: Sales then Loss Revenue; tap a Sales store row and confirm `store | district | market`  
4. Share → Dashboard: counts filled, markets expanded, numbers not wrapped  
5. Menu / Back pills

## Screenshots to capture before generate
- TestFlight Update (reuse IMG_0181 / IMG_0179 if unchanged)
- Upload / Choose file (reuse IMG_0182–0185)
- Dashboard Sales + Loss Revenue cards
- Sales ScoreCard store table with full `3607 | A9 | Mid-Atlantic`
- Share email 5 Star + markets block
- Header showing Menu and Back pills

## Generate
```bash
cd docs/aci-guides
# Update make_guide.py BUILD = 352 and STAMP = HB-0827.81
# Point STEPS at the new screenshots
python3 make_guide.py
```
