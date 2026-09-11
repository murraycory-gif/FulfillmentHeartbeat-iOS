# HB-0828.407 / 733 — verify (THIS SEAT chips + phone density)

**Tip** `origin/cursor/command-center-8b-3389` · [PR #5](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/5)  
**Stamp** `HB-0828.407  1.0 (733)` · bundle `com.corymurray.FulfillmentHeartbeat`  
**No TestFlight until this PASSes.** Do not delete the app. Cloud Linux cannot `xcodebuild` or talk to a Mac/iPad (no self-hosted worker registered).

## CoS first — Mac Catalyst (over existing app)

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS   # or your checkout
./install-mac.sh                          # Debug Catalyst, tip SHA
# CONFIGURATION=Release ./install-mac.sh  # optional second smoke
./Tools/HeartbeatIngest/verify-stale-seat-refresh.sh
```

Quit Heartbeat from the **Dock** (not just the window). Reopen.

| Check | Pass |
|---|---|
| Sidebar stamp | `HB-0828.407  1.0 (733)` |
| Sales | **~$58M** and **Thursday / `sales_d4`** (not ~$49M / Wednesday) |
| Automated test | `testArchitecture406SeatChipsFalseZeroBanAndLiveKeys` + `testArchitecture407PhoneDensitySoftKeep` green |
| Company tables | Visible page / chrome only — not all 12 cards rebuilt into RAM |
| THIS SEAT | Every section live when the hero is live. No ghost dashes/zeros. Healthy/Watch/At Risk washes like Regions. |
| Share Mail | Share pulse → one page **or** multi-select → Send → **Mail stays up**. |
| Mac Picker | Top Opportunity Pickers table shows Shopper / Hours / PPH / Orders / Presub / OTT / OTH5 / COE / Status headers (MUST H — Mac FAIL, not iPad). |
| Mac readability | Command Center + every section is **bigger / easier** (type, cards, tables, status chips, filter chrome). Not phone-dense. Phone D1–D5 stay phone-only. |

## QC — iPhone (THIS SEAT)

Keep the **old local company seat**. Install tip **over** the current build.

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git fetch origin cursor/command-center-8b-3389
git checkout cursor/command-center-8b-3389
git reset --hard origin/cursor/command-center-8b-3389
SKIP_PULL=1 ALLOW_PHONE=1 ./install-ipad.sh
```

1. Confirm stamp **HB-0828.407  1.0 (733)**. Pages only — no phone Back chevron. Tighter CC / section cards.
2. **Force-quit.** Reopen. Do **not** delete.
3. 5 Star: Rating / Flash / COE / OTT / Pre-Sub / OTH — not On-time / Fill / Quality dashes.
4. Pick Path THIS SEAT = Path % / AVG PPH (same as Regions). No ghost Exceptions 0 from `exception_count`.
5. Prep THIS SEAT = PNR % / Goal / Watch (same as Regions). No ghost Not Ready / Orders Due 0.
6. Picker: Shoppers / Opportunity / Doing Well match chrome 27,458 — not 0/0/0.
7. Labor: Weeks is a real week id or omitted — never "—". Cost Tgt / TVA match -0.10%.
8. Dynacap Util % and Schedule Over / Under live from `utilization_pct` / `over_scheduled` / `under_scheduled`.
9. Share Send still presents Mail after the sheet dismisses.
10. Phone header is Pages + Filters + banner only — **no Back**. Command Center / section cards are the denser 407 chrome. iPad leftover-fill unchanged.
11. **Mac Catalyst:** Picker ScoreCard → Top Opportunity Pickers has column headers above live rows. Phone cards stay headerless.
12. **Mac Catalyst readability (MUST M):** Pages, Command Center heroes/glance, section tables, status chips, and Filters are larger than iPad/phone. A narrow Mac window must **not** flip to phone compact chrome. iPhone stays the tighter 407 density.

UDID `676FA816-88AE-59D9-A89D-5C17BFC2DA96` if you target that iPad.

## After PASS

CoS + QC ship TestFlight. Do not upload TF from the agent. Do not merge until CoS says.
