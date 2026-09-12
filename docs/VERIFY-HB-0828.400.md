# HB-0828.423 / 749 — verify (Command Center dashboard paints on filter)

**Tip** `origin/cursor/command-center-8b-3389` · [PR #5](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/5)
**Stamp** `HB-0828.423  1.0 (749)` · bundle `com.corymurray.FulfillmentHeartbeat`
**No TestFlight until this PASSes.** HARD TF HOLD until **dashboard-on-filter** + Clear + section boxes + swap feel + thermal PASS on **iPhone, iPad, and Mac**.

Soft FAIL `c59c1fc` / .422 / 748: on Command Center, filter / Clear left glance + hero numbers stale. Opening Sales showed the correct page. Back to dashboard — then the tiles finally updated. 748 rewrote section box maps; dashboard tiles were snapshots inside GeometryReader. That closure only re-runs on size / appear (navigation), not on `seatPaintStamp`. Warm dashboard host (`shouldKeepDashboardHostWarm`) made the freeze obvious.

## CoS first — Mac Catalyst (over existing app)

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
./install-mac.sh
./Tools/HeartbeatIngest/verify-stale-seat-refresh.sh
```

Stay on **Command Center**. Do not open a section first.

| Check | Pass |
|---|---|
| Sidebar stamp | `HB-0828.423  1.0 (749)` |
| **Dashboard-on-filter** | District / OM / Store / Clear: hero + at-a-glance numbers rewrite the same turn. No navigate-away. |
| **Section boxes (748)** | Open Sales after a filter: THIS WEEK / THIS SEAT already match chrome. |
| **Clear identity** | District → Clear: company Stores N (2161) on dashboard and Sales. Not leftover 612. |
| Filter feel / cool | LRU ≤2. No PulseCaches / expand / grain storm. No xlsx cook. Idle CPU near-zero. |
| Automated test | `testArchitecture423CommandCenterDashboardPaintsOnFilter` + 422/421/420/419/418 |
| Share / Mac chrome | MUST 8 / SEND / MUST K / MUST H / MUST M stand |

## Soft KEEP

| KEEP | Status |
|---|---|
| **Dashboard cards bind `seatPaintStamp` / live `summary`** | Soft KEEP this root |
| Box maps rewrite same turn as chrome (748) | Soft KEEP |
| Clear MUST 1–5 (744) | Soft KEEP FILE ROOT |
| 745 in-place paint when plane exists | Soft KEEP |
| Tiny LRU ≤2 + company pin (746) | Soft KEEP |
| Idle / no xlsx cook (747) | Soft KEEP |
| Remount / `filterStamp` / SQL-reload bans stay **false** | Soft KEEP |
| MUST P `PulseSeatPack` vs `a9e2f68` | Soft KEEP |
| HARD LINE 1 — `companySeatMaxBytes == 28_000_000` | Soft KEEP |
| iPhone D1–D5 / iPad 132/120 / MUST M / MUST H / MUST 8 | Soft KEEP |

## QC — iPhone + iPad

```bash
SKIP_PULL=1 ALLOW_PHONE=1 ./install-ipad.sh
```

1. Stamp **HB-0828.423  1.0 (749)**. Do not delete the app.
2. **iPhone / iPad / Mac:** stay on Command Center. Filter + Clear. Heroes and glance tiles move with chrome. Then open Sales — page already matches. Back — dashboard still matches.

## After PASS

CoS + QC ship TestFlight. Do not upload TF from the agent.
