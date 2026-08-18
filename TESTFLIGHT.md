# Share Fulfillment Heartbeat with testers

Use **TestFlight**. People you invite install the TestFlight app, get Heartbeat
on their iPad, and tap **Update** whenever you ship a new build. You keep
building in Xcode the same way you do today.

## One-time setup (you)

1. In Xcode, open `FulfillmentHeartbeat.xcworkspace`.
2. Select the **FulfillmentHeartbeat** target → **Signing & Capabilities**.
3. Confirm **Automatically manage signing** and your **Team**.
4. Product menu → **Archive**.
5. When Organizer opens, click **Distribute App** → **App Store Connect** → **Upload**.
6. On [App Store Connect](https://appstoreconnect.apple.com):
   - **Apps** → **+** → New App (first time only)
   - Name: **Fulfillment Heartbeat**
   - Bundle ID: `com.corymurray.FulfillmentHeartbeat`
   - Open the app → **TestFlight** tab

Wait until the build finishes processing (usually 5–15 minutes). Status becomes **Ready to Test**.

## Invite people you choose

### Internal (fastest — your store team, same Apple org)

1. App Store Connect → **Users and Access** → add their Apple ID email.
2. Role: **Developer** or **Marketing** is enough.
3. TestFlight → **Internal Testing** → add them to a group (create **Ops testers**).
4. They get an email. On the iPad they install **TestFlight** from the App Store,
   accept, and install **Heartbeat**.

### External (anyone with an Apple ID, not on your team)

1. TestFlight → **External Testing** → new group.
2. Add emails.
3. The **first** external build needs a short “What to Test” note and Apple’s
   Beta App Review (usually a day). After that, later builds can skip review.

They only see the app if you add them. You can remove someone anytime.

## Ship an update later

Every time you want testers to get new work:

1. Pull latest: `cd ~/Developer/FulfillmentHeartbeat-iOS && ./update.sh`
2. Confirm the **build ID** in the top-right of the app (example: `HB-0818.4  1.0 (4)`).
3. Bump the build number if you haven’t already (Xcode target → General → Build).
4. **Product → Archive** → **Distribute App** → Upload.
5. In TestFlight, add that new build to the tester group.

Testers open **TestFlight** and tap **Update**. They do **not** need Xcode or git.

Ask them to tell you the build ID in the top-right if something looks old.

## What testers need

- An iPad (or iPhone) signed into their Apple ID
- The **TestFlight** app
- The email invite you sent

Their data stays on their device. Uploading a workbook on your iPad does not
change theirs.

## Fastlane (optional)

If you already use Fastlane on this Mac:

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
bundle exec fastlane beta
```

That archives and uploads. You still add testers in App Store Connect.
You need either an App Store Connect API key or to sign in when Fastlane asks.
