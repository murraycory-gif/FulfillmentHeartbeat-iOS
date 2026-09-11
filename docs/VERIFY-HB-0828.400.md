# HB-0828.405 / 731 — verify (THIS SEAT chips)

**Tip** `origin/cursor/command-center-8b-3389` · [PR #5](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/5)  
**Stamp** `HB-0828.405  1.0 (731)` · bundle `com.corymurray.FulfillmentHeartbeat`  
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
| Sidebar stamp | `HB-0828.405  1.0 (731)` |
| Sales | **~$58M** and **Thursday / `sales_d4`** (not ~$49M / Wednesday) |
| Automated test | `testArchitecture405SeatChipsUseDashboardKeysNotGhosts` green |
| Company tables | Visible page / chrome only — not all 12 cards rebuilt into RAM |
| THIS SEAT | 5 Star / Pick Path / Prep / Picker chips live when the hero is live. No dashes/zeros from ghost keys. Chips use Healthy/Watch/At Risk washes like Regions. |
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

1. Confirm stamp **HB-0828.405  1.0 (731)**.
2. **Force-quit.** Reopen. Do **not** delete.
3. 5 Star: THIS SEAT shows Rating / Flash / COE / OTT / Pre-Sub / OTH — not On-time / Fill rate / Quality dashes.
4. Pick Path: THIS SEAT shows Path % (~79.7%) and AVG PPH — not Exceptions 0.
5. Prep Not Ready: THIS SEAT shows PNR % (~2.8%), Goal, Watch — not Not Ready 0 / Orders Due 0 / Avg Late dash. Chips pink/red when At Risk (same as Regions).
6. Picker: THIS SEAT Shoppers / Healthy / Watch / At Risk match the 27,458 hero — not 0/0/0.
7. Share Send still presents Mail after the sheet dismisses.

UDID `676FA816-88AE-59D9-A89D-5C17BFC2DA96` if you target that iPad.

## After PASS

CoS + QC ship TestFlight. Do not upload TF from the agent. Do not merge until CoS says.
