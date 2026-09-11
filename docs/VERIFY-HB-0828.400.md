# HB-0828.406 / 732 — verify (THIS SEAT chips)

**Tip** `origin/cursor/command-center-8b-3389` · [PR #5](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/5)  
**Stamp** `HB-0828.406  1.0 (732)` · bundle `com.corymurray.FulfillmentHeartbeat`  
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
| Sidebar stamp | `HB-0828.406  1.0 (732)` |
| Sales | **~$58M** and **Thursday / `sales_d4`** (not ~$49M / Wednesday) |
| Automated test | `testArchitecture406SeatChipsFalseZeroBanAndLiveKeys` green |
| Company tables | Visible page / chrome only — not all 12 cards rebuilt into RAM |
| THIS SEAT | Every section live when the hero is live. No ghost dashes/zeros. Healthy/Watch/At Risk washes like Regions. |
| Share Mail | Share pulse → one page **or** multi-select → Send → **Mail stays up**. |

## QC — iPhone (THIS SEAT)

Keep the **old local company seat**. Install tip **over** the current build.

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git fetch origin cursor/command-center-8b-3389
git checkout cursor/command-center-8b-3389
git reset --hard origin/cursor/command-center-8b-3389
SKIP_PULL=1 ALLOW_PHONE=1 ./install-ipad.sh
```

1. Confirm stamp **HB-0828.406  1.0 (732)**.
2. **Force-quit.** Reopen. Do **not** delete.
3. 5 Star: Rating / Flash / COE / OTT / Pre-Sub / OTH — not On-time / Fill / Quality dashes.
4. Pick Path: Path % live. Exceptions = total − compliant (not 0) when Compliant / Total are live.
5. Prep: PNR % live. Not Ready is not a ghost 0 when the hero is 2.8%.
6. Picker: Shoppers / Opportunity / Doing Well match chrome 27,458 — not 0/0/0.
7. Labor: Weeks is a real week id or omitted — never "—". Cost Tgt / TVA match -0.10%.
8. Dynacap Util % and Schedule Over / Under live from `utilization_pct` / `over_scheduled` / `under_scheduled`.
9. Share Send still presents Mail after the sheet dismisses.

UDID `676FA816-88AE-59D9-A89D-5C17BFC2DA96` if you target that iPad.

## After PASS

CoS + QC ship TestFlight. Do not upload TF from the agent. Do not merge until CoS says.
