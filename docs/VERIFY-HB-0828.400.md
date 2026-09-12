# HB-0828.422 / 748 — verify (section boxes same turn as chrome)

**Tip** `origin/cursor/command-center-8b-3389` · [PR #5](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/5)
**Stamp** `HB-0828.422  1.0 (748)` · bundle `com.corymurray.FulfillmentHeartbeat`
**No TestFlight until this PASSes.** HARD TF HOLD until Clear + **visibility** + swap feel + thermal + idle CPU PASS on **iPhone, iPad, and Mac**.

Soft FAIL `f1b9a76` / .421 / 747: after filter Clear/swap, hero/chrome moved but THIS WEEK / THIS SEAT (and other section boxes) lagged or stayed leftover until the section was tapped. Same dual-identity class as Clear FAIL 743. Chrome wrote `cachedSummaries`. Boxes read `seatRows` → `latestBySection` / `filteredLatest`. LRU=2 evicted the incoming plane so `applyCachedSeatRowPlane` no-op’d and leftover rows stayed. Coalesce + skipRedundant ate the stamp. Thin install filled maps later. Tap only flipped local `@State`.

## CoS first — Mac Catalyst (over existing app)

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
./install-mac.sh
./Tools/HeartbeatIngest/verify-stale-seat-refresh.sh
```

Quit Heartbeat from the **Dock**. Reopen. Do **not** delete the app.

| Check | Pass |
|---|---|
| Sidebar stamp | `HB-0828.422  1.0 (748)` |
| **Visibility** | District / OM / Store / Clear: THIS WEEK / THIS SEAT / status boxes update the same turn as chrome. No tap-to-refresh. |
| **Clear identity** | District → Clear: company Stores N (2161) on hero, THIS WEEK, THIS SEAT, expand — not leftover 612. |
| **Filter feel** | Cached plane stays snappy. LRU miss still rewrites maps in-place (thin pack read). No PulseCaches / expand / grain on the tap. |
| Idle CPU | Near-zero after paint. No 270% xlsx cook. |
| Memory | Flip 6+ seats. RAM does not grow without bound. LRU ≤2 + company pin. |
| Automated test | `testArchitecture422BoxMapsRewriteSameTurnAsChrome` + 421/420/419/418 Soft KEEP |
| Share / Mac chrome | MUST 8 / SEND / MUST K / MUST H / MUST M stand |

## Soft KEEP

| KEEP | Status |
|---|---|
| Clear MUST 1–5 row plane + chrome same turn | Soft KEEP FILE ROOT (744) |
| 745 in-place paint / no pack reinstall when plane exists | Soft KEEP |
| Tiny LRU — company pin + one live plane | Soft KEEP (746) |
| Idle/after-open: no xlsx ingest/cook | Soft KEEP (747) |
| **Box maps rewrite same turn as chrome, even on LRU miss** | Soft KEEP this root |
| Remount bans stay **false** | Soft KEEP |
| `shouldReloadSectionSQLOnSeatPaintStamp` stays **false** | Soft KEEP |
| Company expand / grain Jetsam gates stay **false** | Soft KEEP |
| MUST P `PulseSeatPack` vs `a9e2f68` | Soft KEEP — no cook / PTR |
| HARD LINE 1 — `companySeatMaxBytes == 28_000_000` | Soft KEEP |
| iPhone D1–D5 / iPad 132/120 / MUST M / MUST H / MUST 8 | Soft KEEP |

## QC — iPhone + iPad

```bash
SKIP_PULL=1 ALLOW_PHONE=1 ./install-ipad.sh
```

1. Stamp **HB-0828.422  1.0 (748)**. Do not delete the app.
2. **iPhone:** On a section page, District → OM → Store → Clear. Boxes + numbers move with chrome. No remount flash, no Jetsam.
3. **iPad:** same seats. Company expand stays page-scoped.
4. **Mac:** stay on Sales (or any section). Filter + Clear. THIS WEEK / THIS SEAT update without clicking the section again.

## After PASS

CoS + QC ship TestFlight. Do not upload TF from the agent.
