# HB-0828.420 / 746 — verify (tiny seat-plane LRU; no PulseCaches on filter tap)

**Tip** `origin/cursor/command-center-8b-3389` · [PR #5](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/5)
**Stamp** `HB-0828.420  1.0 (746)` · bundle `com.corymurray.FulfillmentHeartbeat`
**No TestFlight until this PASSes.** HARD TF HOLD until Clear + swap feel + thermal + memory PASS on **iPhone, iPad, and Mac**. Soft FAIL `90a53cd` / .419 / 745: `applyFilters` remembered a full `latestBySection` / `filteredLatest` / grain copy per District / OM / Store with no LRU. Repeat paints skipped reinstall so planes accumulated. First visit still ran `PulseCaches.build`. Mac ingest could still parse xlsx and cook seats in-process (~270% CPU, OOM). Shared path — not Mac-only, not a Timer.

## CoS first — Mac Catalyst (over existing app)

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
./install-mac.sh
./Tools/HeartbeatIngest/verify-stale-seat-refresh.sh
```

Quit Heartbeat from the **Dock**. Reopen. Activity Monitor: after Command Center is up, **CPU near idle**. Memory must not climb while flipping District / OM / Store / Clear.

| Check | Pass |
|---|---|
| Sidebar stamp | `HB-0828.420  1.0 (746)` |
| Idle CPU | Near-zero after paint. No 270% loop. |
| Memory | Flip 6+ seats. RAM does not grow without bound. App stays up (no OOM / Jetsam). |
| **Filter feel** | District / OM / Store / Clear: hero + sections + tables on the tap. No PulseCaches / expand / company grain rebuild. |
| **Clear identity** | District → Clear: company Stores N (2161) on hero, THIS WEEK, THIS SEAT, expand — not leftover 612. |
| Company seat | Thin ≤28MB. Never a ~56MB market file. No xlsx ingest after seat painted. |
| Automated test | `testArchitecture420SeatPlaneTinyLRUNoFullCaches` + 419/418 Soft KEEP |
| Share / Mac chrome | MUST 8 / SEND / MUST K / MUST H / MUST M stand |

## Soft KEEP

| KEEP | Status |
|---|---|
| Clear MUST 1–5 row plane + chrome same turn | Soft KEEP FILE ROOT (744) |
| 745 in-place paint / no pack reinstall when plane exists | Soft KEEP |
| Tiny LRU — company pin + one live plane | Soft KEEP this root |
| No `PulseCaches.build` / expandTables / company grain on filter tap | Soft KEEP this root |
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

1. Stamp **HB-0828.420  1.0 (746)**. Do not delete the app.
2. **iPhone:** District → OM → Store → Clear. Identity agrees. No heat, no Jetsam, no remount flash.
3. **iPad:** same seats. Company expand stays page-scoped. App stays up.
4. **Mac:** Activity Monitor idle after paint. Memory stable across many seat flips.

## After PASS

CoS + QC ship TestFlight. Do not upload TF from the agent.
