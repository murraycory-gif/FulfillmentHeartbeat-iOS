# HB-0828.424 / 750 — verify (CC summaries + compile-clean dashboard paint)

**Tip** `origin/cursor/command-center-8b-3389` · [PR #5](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/5)
**Stamp** `HB-0828.424  1.0 (750)` · bundle `com.corymurray.FulfillmentHeartbeat`
**No TestFlight until this PASSes.** HARD TF HOLD until **dashboard-on-filter** + Clear + section boxes PASS on **iPhone, iPad, and Mac**.

Soft FAIL `130a7ef` / .423 / 749:
1. Catalyst compile: `commandCenterBody` opaque return; `CommandCenterLayout.paintedCard` read `seatPaintStamp` / `summary(for:)` off MainActor.
2. Architecture: CC tiles bind `summary(for:)` → `cachedSummaries` (not @Published). skipRedundant can skip `applyDashChrome` on swap. Coalesce may eat the stamp. Warm DashboardView only re-shows on open+back.

748 section box maps HOLD. This root rewrites CC summaries the same turn as box maps (thin — not a second `applyDashChrome` / PulseCaches storm).

## CoS first — Mac Catalyst (over existing app)

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
./install-mac.sh
```

Must **compile**. Stay on Command Center. Do not open a section first.

| Check | Pass |
|---|---|
| Sidebar stamp | `HB-0828.424  1.0 (750)` |
| **Compile** | Mac Catalyst + iOS. No opaque-return / MainActor isolation FAIL. |
| **Dashboard-on-filter** | District / OM / Store / Clear: hero + glance rewrite the same turn. No Sales open+back. |
| **Section boxes (748)** | Open Sales after a filter: THIS WEEK / THIS SEAT already match. |
| **Clear identity** | District → Clear: company 2161 on dashboard and Sales. Not leftover 612. |
| Cool / LRU | ≤2 planes. No xlsx cook. No PulseCaches / expand on tap. |
| Automated test | `testArchitecture424CommandCenterSummariesRewriteWithBoxMaps` + 423/422/421 KEEP |

## Soft KEEP

| KEEP | Status |
|---|---|
| CC summaries rewrite with box maps; tiles bind stamp on MainActor | Soft KEEP this root |
| 748 box maps same turn + stamp-after-ready | Soft KEEP |
| 744 Clear / 745 skipRedundant heavy chrome / remount bans **false** | Soft KEEP |
| `shouldReloadSectionSQLOnSeatPaintStamp` **false** | Soft KEEP |
| LRU ≤2 / idle 747 / MUST P / 28MB | Soft KEEP |

## QC

```bash
SKIP_PULL=1 ALLOW_PHONE=1 ./install-ipad.sh
```

Same dashboard-on-filter on iPhone + iPad. Do not delete the app.

## After PASS

CoS + QC ship TestFlight. Do not upload TF from the agent.
