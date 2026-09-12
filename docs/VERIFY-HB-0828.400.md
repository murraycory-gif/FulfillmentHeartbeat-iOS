# HB-0828.421 / 747 — verify (idle/after-open no hot loop; Clear + snappy KEEP)

**Tip** `origin/cursor/command-center-8b-3389` · [PR #5](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/5)
**Stamp** `HB-0828.421  1.0 (747)` · bundle `com.corymurray.FulfillmentHeartbeat`
**No TestFlight until this PASSes.** HARD TF HOLD until Clear + swap feel + thermal + memory + **idle CPU** PASS on **iPhone, iPad, and Mac**.

Soft FAIL `90a53cd` / .419 / 745: Mac process **FulfillmentHeartbeat** (Debug Catalyst / HeartbeatMacCatalystBuild) sat at **~270% CPU idle/after open**. After company seat paint, Mac still started `ingestWorkbookOnMacIfNeeded` → download Daily Report xlsx → `runMasterImport` → `publishCloudPack` / `cookPublished` of every store. `fillAfterReady` then ran `lockPickerDashboard` + picker SQL on MainActor. Catalyst `macScrollingHome` flipped `.scrollIndicators` from `overflows()` (GeometryReader layout loop). Shared path — not a Timer, not remount-as-cooldown.

## CoS first — Mac Catalyst (over existing app)

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
./install-mac.sh
./Tools/HeartbeatIngest/verify-stale-seat-refresh.sh
```

Quit Heartbeat from the **Dock**. Reopen. Activity Monitor: after Command Center is up, **CPU near idle** (not ~270%). Memory must not climb while flipping District / OM / Store / Clear.

| Check | Pass |
|---|---|
| Sidebar stamp | `HB-0828.421  1.0 (747)` |
| **Idle CPU** | Near-zero after paint. No 270% loop. No xlsx ingest / cook / dropped-workbook watch. |
| Memory | Flip 6+ seats. RAM does not grow without bound. App stays up (no OOM / Jetsam). |
| **Filter feel** | District / OM / Store / Clear: hero + sections + tables on the tap. No PulseCaches / expand / company grain rebuild. |
| **Clear identity** | District → Clear: company Stores N (2161) on hero, THIS WEEK, THIS SEAT, expand — not leftover 612. |
| Company seat | Thin ≤28MB. Never a ~56MB market file. No xlsx ingest after seat painted. |
| Automated test | `testArchitecture421IdleAfterOpenNoHotLoop` + 420 LRU / 419 / 418 Soft KEEP |
| Share / Mac chrome | MUST 8 / SEND / MUST K / MUST H / MUST M stand |

## Soft KEEP

| KEEP | Status |
|---|---|
| Clear MUST 1–5 row plane + chrome same turn | Soft KEEP FILE ROOT (744) |
| 745 in-place paint / no pack reinstall when plane exists | Soft KEEP |
| Tiny LRU — company pin + one live plane | Soft KEEP (746) |
| No `PulseCaches.build` / expandTables / company grain on filter tap | Soft KEEP (746) |
| **Idle/after-open: no xlsx ingest/cook, no picker fill-after-ready, no indicator layout-loop** | Soft KEEP this root |
| Remount bans stay **false** | Soft KEEP |
| Company expand / grain Jetsam gates stay **false** | Soft KEEP |
| MUST P `PulseSeatPack` vs `a9e2f68` | Soft KEEP — no cook / PTR |
| HARD LINE 1 — `companySeatMaxBytes == 28_000_000` | Soft KEEP |
| No remount / filterStamp / wipe-redownload as cooldown | Soft KEEP |
| iPhone D1–D5 / iPad 132/120 / MUST M / MUST H / MUST 8 | Soft KEEP |

## QC — iPhone + iPad

```bash
SKIP_PULL=1 ALLOW_PHONE=1 ./install-ipad.sh
```

1. Stamp **HB-0828.421  1.0 (747)**. Do not delete the app.
2. **iPhone:** District → OM → Store → Clear. Identity agrees. No heat, no Jetsam, no remount flash.
3. **iPad:** same seats. Company expand stays page-scoped. App stays up.
4. **Mac:** Activity Monitor idle after paint. Clear still company 2161 everywhere. Filter chips still snappy. Memory stable across many seat flips.

## After PASS

CoS + QC ship TestFlight. Do not upload TF from the agent.
