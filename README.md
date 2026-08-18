# Fulfillment Heartbeat iOS

Native **SwiftUI** fulfillment ops dashboard for **iPad first**, iPhone next.

Four sections — **5 Star Metrics**, **Pick Path Compliance**, **Prep Not Ready**,
and **Dynacap Setting** — with Excel / CSV upload and Division / Operations OM /
Store Number filters.

Same EnviroMap color theme. Same workflow as EnviroMap and FamilyHub: Xcode
project in git, Fastlane for Mac builds.

## Open in Xcode

```bash
cd ~/Developer
git clone https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS.git
cd FulfillmentHeartbeat-iOS
open FulfillmentHeartbeat.xcodeproj
```

1. Select the **FulfillmentHeartbeat** scheme and an **iPad** simulator (or your iPad).
2. Signing & Capabilities → choose your Team (automatic signing).
3. Run.

Pull later updates without losing your Apple team:

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
./update.sh
```

Or `git pull` then reopen the project.

## What’s in this foundation

| Area | Status |
|------|--------|
| iPad split view + iPhone tabs | Working |
| 5 Star / Pick Path / Prep NR / Dynacap cards | Working |
| Division / OM / Store filters | Working |
| Excel (.xlsx) + CSV upload | Working (new file replaces that section) |
| Sample Chicago market | Working |
| Per-section store table + trend | Working |
| JSON store in Application Support | Working (`HeartbeatStore`) |
| Your logo | Drop in when you have it |
| iCloud / multi-device | Later |
| Live Walmart report sync | Later |

Data lives on-device as JSON in Application Support (`HeartbeatStore`), same
idea as FamilyHub’s `HubStore` and EnviroMap’s `SessionStore`.

Workbook headers are flexible — `Division`, `Operations OM`, `Store Number`
(and common aliases) are mapped automatically. Templates are in `Templates/`
and also exportable from the Upload screen.

## Automated testing (Fastlane)

See [FASTLANE.md](FASTLANE.md).

```bash
bundle install
bundle exec fastlane qa
```

## Open items

See [OPEN_ITEMS.md](OPEN_ITEMS.md).
