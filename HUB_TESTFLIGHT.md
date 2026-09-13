# HUB Prediction — TestFlight (iPhone)

Own product. Not Heartbeat. Not the Heartbeat TestFlight build.

| | |
|---|---|
| App Store Connect name | **HUB Prediction** (already created) |
| Home-screen name | **HUB Pred** |
| Bundle ID | `com.corymurray.HubPrediction` |
| Team | `M7FL68Q43A` |
| Project | `HubPrediction.xcodeproj` |
| Branch | `cursor/hub-prediction-core-5071` |

The phone calls Kalshi + Coinbase itself. The Mac can be off after install.

## Upload from the Mac (do this)

Xcode must already have your Apple ID (Settings → Accounts) and team **M7FL68Q43A**.

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git fetch origin
git checkout cursor/hub-prediction-core-5071
git pull
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
open HubPrediction.xcodeproj
```

In Xcode:

1. Scheme **HubPrediction** (not FulfillmentHeartbeat).
2. Target **HubPrediction** → **Signing & Capabilities** → Automatically manage signing → Team `M7FL68Q43A`.
3. **Product → Archive**.
4. Organizer → **Distribute App** → **App Store Connect** → **Upload**.
5. App Store Connect → **HUB Prediction** → TestFlight → Internal group → add yourself.
6. iPhone TestFlight → install **HUB Pred**.

Optional script after signing works once:

```bash
./push-hub-testflight.sh
```

Do **not** run `./push-testflight.sh` — that is Heartbeat.

## First-time App Store Connect

Already done if you see **HUB Prediction** in Apps. The access-settings warning can be ignored.

If the bundle ID was missing from the dropdown, register `com.corymurray.HubPrediction` under Identifiers, then pick it.

SKU (internal): `hub-prediction`.
