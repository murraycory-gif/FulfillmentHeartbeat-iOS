# HB-0828.403 / 729 — verify (one page)

**Tip** `origin/cursor/command-center-8b-3389` · [PR #5](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/5)  
**Stamp** `HB-0828.403  1.0 (729)` · bundle `com.corymurray.FulfillmentHeartbeat`  
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
| Sidebar stamp | `HB-0828.403  1.0 (729)` |
| Sales | **~$58M** and **Thursday / `sales_d4`** (not ~$49M / Wednesday) |
| Automated test | `testStaleCompanySeatIsReplacedByNewerCloudPackWithoutDelete` green |
| Company tables | Visible page / chrome only — not all 12 cards rebuilt into RAM |
| Share Mail | Share pulse → Share 1 page → Send → **Mail stays up**. iPhone Mail: Regions columns readable (stacked cards, not clipped). Picker Healthy / Watch / At Risk match in-app, not 0. |

## QC — iPhone / iPad (primary E2E)

Keep the **old local company seat**. Install tip **over** the current build.

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git fetch origin cursor/command-center-8b-3389
git checkout cursor/command-center-8b-3389
git reset --hard origin/cursor/command-center-8b-3389
SKIP_PULL=1 ./install-ipad.sh                 # iPad
# SKIP_PULL=1 ALLOW_PHONE=1 ./install-ipad.sh  # iPhone
```

1. Confirm stamp **HB-0828.403  1.0 (729)**.
2. **Force-quit.** Reopen. Do **not** delete.
3. Sales must move **~$49M / Wednesday → ~$58M / Thursday `sales_d4`**.
4. Lower tables on the **visible** page load. App stays up (no Jetsam / no close).
5. Background → foreground: Sales stays Thursday.
6. Clear / District 03 still paint from seat files.
7. **P0 Share Send:** Mail stays up. Open the recap on **iPhone Mail**: Loss / 5 Star Regions cards must be readable (not clipped off the right). Picker ScoreCard Healthy / Watch / At Risk must match the app.

UDID `676FA816-88AE-59D9-A89D-5C17BFC2DA96` if you target that iPad.

## After PASS

CoS + QC ship TestFlight. Do not upload TF from the agent. Do not merge until CoS says.
