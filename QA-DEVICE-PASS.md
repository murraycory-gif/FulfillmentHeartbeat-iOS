# Device QA — PASS before TestFlight

Stamp must read **HB-0828.379  1.0 (702)**. Force-quit the app, then run this list on UDID `676FA816-88AE-59D9-A89D-5C17BFC2DA96`. Do not TF until every line is PASS. Do not merge from this checklist.

## Boot / Who’s looking

1. Force-quit → cold launch.
2. Load screen: Fulfillment wordmark + heart + pulse **centered**.
3. Halloween Canvas parade jumps **over** the progress line (no Lottie / video / GIF).
4. Grocery copy is under the parade (rotisserie / pumpkin / watermelon — not “ice cream aisle”).
5. Seats stay **locked** until the pack is on the floor (readiness gate).
6. Stamp **HB-0828.379  1.0 (702)**. No Jetsam / crash on the load.

## District 03 seat

7. Continue as District 03.
8. Operational Heartbeat / roster cards show **Stores 20**.
9. Dynacap Stores **20**.
10. **Picker ScoreCard:** headline **> 0**, shopper buckets live, Stores footer live (not gray / NO DATA).
11. Open every sidebar page (Sales, Loss Revenue, Missing Items, 5 Star, Pre-sub, Pick Path, Prep, Dynacap, Schedule, Picker, PPH, Labor). None stay empty when the pack has facts.
12. Scroll dashboard and each page — snappy (no remount storm).
13. Sidebar page switches — snappy (warm hosts). Swipe still works.

## Store seat

14. Filter one District 03 store. That store’s cards / Picker stay live (not company-chunk empty).
15. Clear filters: no crash, Regions **4**, company Picker chrome returns.

## Hard locks (must stay false)

- Hub under role gate: off
- Paging scroll: off
- Remount page on destination change: off
- Stamp hub when expand cache fills: off
- Stream picker on Dashboard: off
- Company picker stream on sidebar tap: off
