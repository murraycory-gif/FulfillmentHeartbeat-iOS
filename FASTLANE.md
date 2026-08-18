# FulfillmentHeartbeat — Fastlane

Automates **build** and **unit tests** on your Mac. Same pattern as EnviroMap and FamilyHub.

## One-time setup

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git pull
bundle install
```

If `bundle` is missing:

```bash
sudo gem install bundler
bundle install
```

## Lanes

| Command | What it does |
|---------|----------------|
| `bundle exec fastlane build` | Compile app for iOS Simulator |
| `bundle exec fastlane build_clean` | Clean + compile |
| `bundle exec fastlane tests` | Run `FulfillmentHeartbeatTests` on Simulator |
| `bundle exec fastlane qa` | Build + tests + list open High items |
| `bundle exec fastlane open_items` | Print High+Open rows from `OPEN_ITEMS.md` |
| `bundle exec fastlane device_build` | Build for physical iPad/iPhone (signing required) |
| `bundle exec fastlane sims` | List simulators |

Prefer an iPad simulator:

```bash
export SCAN_DEVICE="iPad (10th generation)"
bundle exec fastlane tests
```

## What Fastlane covers vs device QA

| Automated (Fastlane / Simulator) | Manual (Cory’s iPad) |
|----------------------------------|----------------------|
| Compiles without errors | Sidebar + landscape on iPad |
| CSV header aliases parse | Drop a real 5 Star workbook |
| Health bands + Dynacap 10% rule | Filter Division → OM → store |
| Open-items file present | Replace the placeholder logo |

## Reports

After `tests` or `qa`:

- `build/test_output/report.html`
- `build/test_output/report.junit`

## Troubleshooting

- **No scheme FulfillmentHeartbeat** → open `FulfillmentHeartbeat.xcodeproj` once in Xcode, then re-run
- **Signing errors on device_build** → set Team in Xcode Signing & Capabilities
- **scan device not found** → `fastlane sims` and set `SCAN_DEVICE`
