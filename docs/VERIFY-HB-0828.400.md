# HB-0828.413 / 739 — verify (Mac Share actually opens Mail, never fakes sent)

**Tip** `origin/cursor/command-center-8b-3389` · [PR #5](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/5)
**Stamp** `HB-0828.413  1.0 (739)` · bundle `com.corymurray.FulfillmentHeartbeat`
**No TestFlight until this PASSes.** HARD TF HOLD. Do not delete the app. Cloud Linux cannot `xcodebuild` or talk to a Mac/iPad (no self-hosted worker registered). 413 skips MFMailCompose on Mac (false `.sent`) and opens a Mail draft — user must click Send.

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
| Sidebar stamp | `HB-0828.413  1.0 (739)` — fully visible, not under the dock / window edge |
| Mac compile | `./install-mac.sh` succeeds. `HubSeatPackRefreshModifier` is file-scope next to `HubPhoneTableModifier` — not nested in `extension View`. |
| Sales | **~$58M** and **Thursday / `sales_d4`** (not ~$49M / Wednesday) |
| Automated test | `testArchitecture413MacShareDoesNotFakeSend` + 412/411 Soft KEEP green |
| Company tables | Visible page / chrome only — not all 12 cards rebuilt into RAM |
| THIS SEAT | Every section live when the hero is live. No ghost dashes/zeros. |
| Share Mail | Share pulse → Send → **Mail stays up**. |
| Mac Picker | Top Opportunity headers stay (MUST H). |
| Mac Pages | **No Pages button** in the top brand bar. Sidebar-leading **icon** sits in rail chrome (logo row) — never a floating "Hide pages" label over Loss Revenue / any list row. Icon collapses the rail; slim rail icon reopens it. Center expands and reflows on window resize. |
| Mac clip | **Prep** glance (last row) is fully on-screen or reachable by scroll. No card cut by the window bottom. Resize the window — last row stays in the safe area. Sidebar stamp visible. |
| Mac Share | **New Message** opens at **1100×860**. Navy **Back**, clickable **To**, notes, +/−. Send dismisses the sheet (730 hop) then opens an Apple Mail **draft** (To/subject filled). Heartbeat shows **Finish in Mail** — not “sent”. Click **Send in Mail** or the recipient gets nothing. If Mail cannot open: **Mail did not send** + recap on the clipboard. |
| Pull-to-refresh | Phone / iPad / Mac Command Center + section pages pull the **same** no-delete seat-repull as cold open (remote `updated_at` newer). No hub remount / filterStamp. |

## Soft KEEP (Architecture)

| KEEP | Status |
|---|---|
| Phone D1–D5 compact chrome | Soft KEEP — phone-only |
| iPad leftover-fill 132 / 120 | Soft KEEP — `heroBandHeight(..., mac: false)` still 128 |
| MUST H Mac Picker headers | Soft KEEP |
| Data MUST 1 dual-map deleted | Soft KEEP |
| MUST P cook / seat-repull / expand gates | Soft KEEP — no PulseSeatPack / WorkbookParser / cook edits |
| MUST M Mac readable tokens | Soft KEEP — 408 fits those tokens to the live window instead of overflowing |
| Share Mail presenter | Soft KEEP — dismiss sheet → 350ms → `presentMail` on `keyWindowRoot`. Notes wrap the packet only. Do not edit `writeHTML` / `dataTable` / `presentMail`. |
| Mac Share in-content chrome | MUST — Back + To live in the sheet body on Mac. Do not put compose fields only in the Catalyst navigation bar. |
| Mac sidebar collapse chrome | MUST — icon in rail chrome only. `shouldUseFloatingMacHidePagesLabel() == false`. |
| Pull-to-refresh seat-repull | MUST — same `importCloudSQLiteIfPresent` / remote-newer check as cold open. `shouldStampHubOnPullToRefresh() == false`. MUST P no-delete Soft KEEP. |
| File-scope refresh modifier | MUST — `HubSeatPackRefreshModifier` stays at file scope. Nesting a `ViewModifier` in `extension View` is a compile FAIL. |
| Mac bottom chrome reserve | MUST — `shouldReserveMacWindowBottomChrome()` + scroll overflow. Do not lock CC to exact window height. |
| Mac Share no fake send | MUST — `shouldPresentMFMailComposeOnMac() == false`. `shouldTreatMailtoOpenAsSent() == false`. Mailto/copy is not delivery. |

## QC — iPhone (THIS SEAT)

Keep the **old local company seat**. Install tip **over** the current build.

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git fetch origin cursor/command-center-8b-3389
git checkout cursor/command-center-8b-3389
git reset --hard origin/cursor/command-center-8b-3389
SKIP_PULL=1 ALLOW_PHONE=1 ./install-ipad.sh
```

1. Confirm stamp **HB-0828.413  1.0 (739)**. Pages stays on phone. No phone Back chevron. Tighter CC / section cards.
2. **Force-quit.** Reopen. Do **not** delete.
3. 5 Star / Pick Path / Prep / Picker / Labor THIS SEAT still live keys (MUST 1).
4. Share Send still presents Mail.
5. **Mac:** no top Pages button; sidebar-leading icon in the rail chrome collapses the list — Loss Revenue is fully visible, no Hide pages text on top of it. Command Center **Prep** tile and sidebar stamp stay above the window/dock — scroll if the window is short. Share → New Message: navy Back, clickable To, notes, +/−. Send opens a Mail draft — click Send in Mail. Heartbeat must not say the email was sent.

UDID `676FA816-88AE-59D9-A89D-5C17BFC2DA96` if you target that iPad.

## After PASS

CoS + QC ship TestFlight. Do not upload TF from the agent. Do not merge until CoS says.
