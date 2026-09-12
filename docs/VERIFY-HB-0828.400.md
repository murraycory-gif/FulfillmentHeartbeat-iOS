# HB-0828.418 / 744 — verify (Clear rewrites row plane with company chrome)

**Tip** `origin/cursor/command-center-8b-3389` · [PR #5](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/5)
**Stamp** `HB-0828.418  1.0 (744)` · bundle `com.corymurray.FulfillmentHeartbeat`
**No TestFlight until this PASSes.** HARD TF HOLD until Soft KEEP + Cory phone Clear PASS. Do not delete the app. Cloud Linux cannot `xcodebuild` or talk to a Mac/iPad (no self-hosted worker registered). Soft FAIL `fda1bf0` / .417 / 743: Clear painted company chrome (2161) while PhoneSectionPage kept leftover district `filteredLatest` (THIS WEEK 612). **MUST:** one filter identity — hero + all sections + expand. Clear rewrites the row plane in-place the same turn as chrome. Remount / `filterStamp` is not the fix. MUST 8 / SEND 1–7 / MUST K / MUST P stand. Re-AUDIT this SHA after phone Clear PASS.

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
| Sidebar stamp | `HB-0828.418  1.0 (744)` — fully visible, not under the dock / window edge |
| Mac compile | `./install-mac.sh` succeeds. `HubSeatPackRefreshModifier` is file-scope next to `HubPhoneTableModifier` — not nested in `extension View`. |
| Sales | **~$58M** and **Thursday / `sales_d4`** (not ~$49M / Wednesday) |
| Automated test | `testArchitecture418ClearRewritesRowPlaneWithChrome` + 417 MUST 8 Soft KEEP green |
| Company tables | Visible page / chrome only — not all 12 cards rebuilt into RAM |
| THIS SEAT | Every section live when the hero is live. No ghost dashes/zeros. |
| **Clear identity** | District (or OM) → Clear: hero Stores N, THIS WEEK, THIS SEAT, and expand all show **company** store count (2161), not leftover 612. Labels and golds agree. No hub remount / `filterStamp` flash. |
| Share Mail | Share pulse → Send → **Mail stays up**. |
| Mac Picker | Top Opportunity headers stay (MUST H). |
| Mac Pages | **No Pages button** in the top brand bar. Sidebar-leading **icon** sits in rail chrome (logo row) — never a floating "Hide pages" label over Loss Revenue / any list row. Icon collapses the rail; slim rail icon reopens it. Center expands and reflows on window resize. |
| Mac clip | **Prep** glance (last of 9) is fully visible after scroll. Tiles stay MUST M size (glance floor 196) — do not leftover-fill to `geo.size.height`. `overflows()` is the scroll-indicator gate. Sidebar stamp visible. |
| Mac Share | **New Message** opens at **1100×860**. Navy **Back** + **To** hit-testable above the fold (fields scroll). Send stays disabled until a valid To. Send dismisses the sheet (730 hop) then **MFMailCompose** on `keyWindowRoot`. Empty To never opens mailto. No **Recap sent** toast. Mail compose `.failed` surfaces **Mail did not send**. Recipient inbox must get the email. |
| Pull-to-refresh | Phone / iPad / Mac Command Center + section pages pull the **same** no-delete seat-repull as cold open (remote `updated_at` newer). No hub remount / filterStamp. |

## Soft KEEP (Architecture)

| KEEP | Status |
|---|---|
| Phone D1–D5 compact chrome | Soft KEEP — phone-only |
| iPad leftover-fill 132 / 120 | Soft KEEP — `heroBandHeight(..., mac: false)` still 128 |
| MUST H Mac Picker headers | Soft KEEP |
| Data MUST 1 dual-map deleted | Soft KEEP |
| MUST P cook / seat-repull / expand gates | Soft KEEP — no PulseSeatPack / WorkbookParser / cook / PTR edits |
| MUST M Mac readable tokens | Soft KEEP — 408 fits those tokens to the live window instead of overflowing |
| Share Mail presenter | Soft KEEP — dismiss sheet → 350ms → `presentMail` on `keyWindowRoot`. Notes wrap the packet only. Do not edit `writeHTML` / `dataTable` / `presentMail`. |
| Mac Share in-content chrome | MUST — Back + To live in the sheet body on Mac. Do not put compose fields only in the Catalyst navigation bar. |
| Mac sidebar collapse chrome | MUST C file-only — icon in rail chrome only. `shouldUseFloatingMacHidePagesLabel() == false`. Not Soft KEEP yet. |
| Pull-to-refresh seat-repull | MUST — same `importCloudSQLiteIfPresent` / remote-newer check as cold open. `shouldStampHubOnPullToRefresh() == false`. MUST P no-delete Soft KEEP. |
| File-scope refresh modifier | MUST — `HubSeatPackRefreshModifier` stays at file scope. Nesting a `ViewModifier` in `extension View` is a compile FAIL. |
| Mac Command Center scroll | MUST K — `shouldFillMacViewport() == false`. Readable tiles + ScrollView. `overflows()` is the gate. Do not leftover-fill or paper slack/minGlance. |
| Mac Share send | MUST 8 + SEND 1–7 Soft KEEP — `MacMailComposer.swift` gone. Hop: dismiss → 350ms → `keyWindowRoot` → MFMailCompose. |
| Remount bans | Soft KEEP — `shouldStampHubOnClearToCompany` / `shouldStampHubOnFilterSwap` / `shouldRemountPhoneHubOnFilterSwap` / `shouldRemountPageOnDestinationChange` / `shouldStampHubOnPullToRefresh` stay **false**. Expand stays off the gesture thread. |
| Clear row plane | Soft KEEP this root — `shouldRewriteSeatRowPlaneWithChrome() == true`. `shouldDeferSeatInstallWhenRowPlaneMissing() == false`. No `wipeSeatDashboardState` / `restoreUnfilteredChrome` on Clear. `shouldApplySeatSliceOfMarketWarehouse() == false`. |

## QC — iPhone (THIS SEAT)

Keep the **old local company seat**. Install tip **over** the current build.

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git fetch origin cursor/command-center-8b-3389
git checkout cursor/command-center-8b-3389
git reset --hard origin/cursor/command-center-8b-3389
SKIP_PULL=1 ALLOW_PHONE=1 ./install-ipad.sh
```

1. Confirm stamp **HB-0828.418  1.0 (744)**. Pages stays on phone. No phone Back chevron. Tighter CC / section cards.
2. **Force-quit.** Reopen. Do **not** delete.
3. 5 Star / Pick Path / Prep / Picker / Labor THIS SEAT still live keys (MUST 1).
4. **Clear:** District (or OM) on Sales → Clear. Hero, THIS WEEK, THIS SEAT, and expand all show company store count (2161) — not leftover 612. Every section agrees. No remount flash.
5. Share Send still presents Mail.
6. **Mac:** no top Pages button; sidebar-leading icon in the rail chrome collapses the list — Loss Revenue is fully visible, no Hide pages text on top of it. Command Center **Prep** (last of 9) is fully visible after scroll — no leftover-fill clip. Share → New Message: navy Back + To above the fold; Send disabled until a valid To. Send hop → MFMailCompose. No Recap sent toast. Recipient inbox must get the email. Cancel / `.failed` must not claim sent.

UDID `676FA816-88AE-59D9-A89D-5C17BFC2DA96` if you target that iPad.

## After PASS

CoS + QC ship TestFlight. Do not upload TF from the agent. Do not merge until CoS says.
