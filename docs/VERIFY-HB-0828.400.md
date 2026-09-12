# HB-0828.408 / 734 — verify (Mac window-fit + collapsible Pages)

**Tip** `origin/cursor/command-center-8b-3389` · [PR #5](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/5)  
**Stamp** `HB-0828.408  1.0 (734)` · bundle `com.corymurray.FulfillmentHeartbeat`  
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
| Sidebar stamp | `HB-0828.408  1.0 (734)` |
| Sales | **~$58M** and **Thursday / `sales_d4`** (not ~$49M / Wednesday) |
| Automated test | `testArchitecture408MacWindowFitAndCollapsibleRail` + 406/407 Soft KEEP green |
| Company tables | Visible page / chrome only — not all 12 cards rebuilt into RAM |
| THIS SEAT | Every section live when the hero is live. No ghost dashes/zeros. |
| Share Mail | Share pulse → Send → **Mail stays up**. |
| Mac Picker | Top Opportunity headers stay (MUST H). |
| Mac Pages | **No Pages button** in the top brand bar. Hide pages on the rail; collapsed rail reopens it. Center expands and reflows on window resize. |
| Mac clip | Command Center glance / section callouts are fully visible — nothing cut at the window bottom or rail edge. |
| Mac Share | Share / New Message is a **big** pop-out (960×780 default). +/− resizes it. Email preview is large. Notes go into the mail on Send. Mail still dismisses the sheet first (730 hop). |

## Soft KEEP (Architecture)

| KEEP | Status |
|---|---|
| Phone D1–D5 compact chrome | Soft KEEP — phone-only |
| iPad leftover-fill 132 / 120 | Soft KEEP — `heroBandHeight(..., mac: false)` still 128 |
| MUST H Mac Picker headers | Soft KEEP |
| Data MUST 1 dual-map deleted | Soft KEEP |
| MUST P cook / seat-repull / expand gates | Soft KEEP — no PulseSeatPack / WorkbookParser / cook edits |
| MUST M Mac readable tokens | Soft KEEP — 408 fits those tokens to the live window instead of overflowing |
| Share Mail presenter | Soft KEEP — dismiss sheet → 350ms → `presentMail` on `keyWindowRoot`. Notes wrap the packet only. |

## QC — iPhone (THIS SEAT)

Keep the **old local company seat**. Install tip **over** the current build.

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git fetch origin cursor/command-center-8b-3389
git checkout cursor/command-center-8b-3389
git reset --hard origin/cursor/command-center-8b-3389
SKIP_PULL=1 ALLOW_PHONE=1 ./install-ipad.sh
```

1. Confirm stamp **HB-0828.408  1.0 (734)**. Pages stays on phone. No phone Back chevron. Tighter CC / section cards.
2. **Force-quit.** Reopen. Do **not** delete.
3. 5 Star / Pick Path / Prep / Picker / Labor THIS SEAT still live keys (MUST 1).
4. Share Send still presents Mail.
5. **Mac:** no top Pages button; Hide pages collapses the rail; resize the window — callouts and Command Center stay inside the frame.

UDID `676FA816-88AE-59D9-A89D-5C17BFC2DA96` if you target that iPad.

## After PASS

CoS + QC ship TestFlight. Do not upload TF from the agent. Do not merge until CoS says.
