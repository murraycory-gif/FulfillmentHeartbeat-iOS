# HUB Prediction — TestFlight (iPhone)

This is its own iPhone app. It is not Heartbeat. It does not share Heartbeat screens, facts, or the Heartbeat TestFlight build.

- App name: **HUB Pred**
- Bundle ID: `com.corymurray.HubPrediction`
- Team: `M7FL68Q43A`
- Project: `HubPrediction.xcodeproj`

The phone talks to Kalshi and Coinbase directly. Your Mac does not need to stay on.

## First time only — create the App Store Connect app

1. [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App**.
2. Platform **iOS**. Name **HUB Prediction**.
3. Bundle ID **com.corymurray.HubPrediction** (Xcode can create this identifier the first time you archive if it is missing).
4. SKU `hub-prediction`.

Skip this if the app already exists.

## Send a build from your Mac

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git pull
./push-hub-testflight.sh
```

When Organizer opens: **Distribute App** → **App Store Connect** → **Upload**.

Or:

```bash
bundle exec fastlane hub_beta
```

Wait until App Store Connect → **HUB Prediction** → **TestFlight** says **Ready to Test**. Add yourself to an Internal group. Install **TestFlight** on the iPhone, accept, install **HUB Pred**.

Heartbeat testers do not get this app. This TestFlight listing is only HUB Prediction.
