# TestFlight — invite the people you choose

Testers install **TestFlight** from the App Store, then Heartbeat. They tap **Update** when you ship a new build. They do not need Xcode or git.

Current app: **Heartbeat** · bundle `com.corymurray.FulfillmentHeartbeat` · version **1.0** · team `M7FL68Q43A`.

---

## 1. Create the app in App Store Connect (first time only)

1. Open [App Store Connect](https://appstoreconnect.apple.com) with your Apple Developer account.
2. **Apps** → **+** → **New App**.
3. Platform: **iOS**. Name: **Fulfillment Heartbeat**.
4. Bundle ID: **com.corymurray.FulfillmentHeartbeat** (must match Xcode).
5. SKU: `fulfillment-heartbeat` (internal, not shown to testers).
6. User Access: **Full Access**.

If the app already exists, skip this.

---

## 2. Archive and upload from your Mac

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git pull origin main
open FulfillmentHeartbeat.xcworkspace
```

In Xcode:

1. Target **FulfillmentHeartbeat** → **Signing & Capabilities**.
2. **Automatically manage signing** · Team = your team (`M7FL68Q43A`).
3. Scheme **FulfillmentHeartbeat** · Any iOS Device (or **Generic iOS Device**).
4. **Product → Archive**.
5. Organizer → **Distribute App** → **App Store Connect** → **Upload**.
6. Leave “Upload your app’s symbols” on. Upload.

That same iOS archive is the TestFlight build for iPhone, iPad, and Apple silicon Mac (Designed for iPad layout — same screens as the 12-inch iPad).

To also keep a native Mac Catalyst archive:

7. Scheme destination **My Mac (Mac Catalyst)** → **Product → Archive** → upload that archive to the same App Store Connect app.

Mac testers: install **TestFlight** from the Mac App Store → open the Heartbeat invite → **Install**. Window opens at iPad size. Choose file uses the Mac file picker / iCloud Drive.

Wait 5–15 minutes. App Store Connect → the app → **TestFlight**. Build status becomes **Ready to Test**.

Export compliance is already answered in the app (`ITSAppUsesNonExemptEncryption = false`). You should not get a missing-compliance hold.

Optional Fastlane upload (same result):

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
bundle exec fastlane beta
```

---

## 3. Invite only the people you pick

### Internal (fastest — same Apple Developer org)

Use this for store/ops people you already trust and who can be added to your Apple team.

1. App Store Connect → **Users and Access** → **+**.
2. Enter their **Apple ID email**.
3. Role: **Marketing** is enough (they cannot change the app).
4. TestFlight → **Internal Testing** → create group **Ops testers**.
5. Add those users to the group and add the latest build.
6. They get an email → install **TestFlight** on the iPad → Accept → Install **Heartbeat**.

Internal testers get new builds as soon as processing finishes. No Apple review.

### External (anyone with an Apple ID — not on your team)

Use this for people you do not want on the developer account.

1. TestFlight → **External Testing** → **+** group, name **Heartbeat testers**.
2. Add the build.
3. First external build: fill **What to Test** (short) and submit **Beta App Review** (usually hours, sometimes a day). Later builds on the same version often skip review.
4. Add emails, or share a **public link** (you can turn the link off anytime).

They only see the app if you add them. Remove anyone from the group to cut access.

**What to Test** (paste this on the first external build):

> Fulfillment Heartbeat for iPad. Load the master workbook or individual KPI sheets. Check Dashboard, filters (multi-select + Clear), swipe between scorecards, and the Operational Heartbeat Checklist. Confirm store tables and shopper expand match the files you uploaded.

---

## 4. What you send each tester

```
Install TestFlight from the App Store on your iPad.
Open the invite email (or tap the TestFlight link I sent).
Accept, then Install Heartbeat.
Upload your KPI files (or the master workbook) in Upload.
Top-right stamp should read HB-0821.57  1.0 (172) after this build.
Tell me that stamp if something looks old.
```

Their data stays on their device. Your iPad files do not sync to theirs.

---

## 5. Ship the next build

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git pull origin main
open FulfillmentHeartbeat.xcworkspace
```

**Product → Archive** → Upload. Add the new build to the tester group. Testers open TestFlight → **Update**.

Ask them for the top-right stamp if a bug report might be on an old build.
