# Heartbeat lock-screen alerts

The app asks once, after a pack is on screen, then registers its APNs device token with a Cloudflare Worker. The cook pipeline sends one alert per published pack. Nothing in this folder is deployed from the repo.

The alert text is `Heartbeat: new data uploaded Mon 9/28 3:10 PM`. The clock uses `APNS_DISPLAY_TZ` (default `America/Chicago`) and the same pack timestamp as the in-app Updated line (`chrome.publishedAt`, otherwise `written_at`).

Pages → Settings → Notifications has two switches, stored in UserDefaults. Both default to ON. The first time a pack is on screen, Heartbeat asks for the system notification permission so the push toggle can register. New data alerts ON posts the device token with `optedOut: false`. OFF posts the same token with `optedOut: true`. The sender skips those tokens. If permission is denied, the page shows Open iOS Settings on iPhone and iPad, and Open System Settings on Mac.

Mac Catalyst and Designed for iPad use the same `aps-environment` entitlement as the iPhone build (`FulfillmentHeartbeat/FulfillmentHeartbeat.entitlements`, wired by `CODE_SIGN_ENTITLEMENTS` on the app target). Those Mac builds register the token with `env` plus `platform: macos`. iPhone and iPad register `platform: ios`.

## What you set up

1. Apple key. In the Apple Developer account for team `M7FL68Q43A`, create a Key with Apple Push Notifications service (APNs) enabled. Download the `.p8` once. Note the Key ID. The bundle id is `com.corymurray.FulfillmentHeartbeat`.
2. Turn on the Push Notifications capability for that App ID. Debug builds use the `development` entitlement (`APS_ENVIRONMENT`). Release and TestFlight use `production`.
3. Cloudflare account on the free Workers and KV plans. From `Tools/HeartbeatPush/worker`:
   ```sh
   npx wrangler login
   npx wrangler kv namespace create TOKENS
   ```
   Paste the printed namespace id into `wrangler.jsonc` in place of `00000000000000000000000000000000`.
   ```sh
   npx wrangler secret put PUSH_LIST_SECRET
   npx wrangler deploy
   ```
   Copy the workers.dev URL.
4. In the iOS target Info.plist, set `HBPushWorkerURL` to that URL (no trailing path). Ship a build so phones can POST tokens.
5. GitHub Actions secrets on this repo, used by `.github/workflows/cook-heartbeat-pack.yml`:
   - `APNS_KEY_P8` — full `.p8` PEM text
   - `APNS_KEY_ID` — the Key ID
   - `APNS_TEAM_ID` — `M7FL68Q43A` (the sender also defaults to this)
   - `PUSH_WORKER_URL` — the workers.dev URL
   - `PUSH_LIST_SECRET` — the same value as the Worker secret

If `APNS_KEY_P8` or `APNS_KEY_ID` is missing, the cook prints `push skipped: no key` and continues. A missing worker URL prints `push skipped: no worker`. A pack timestamp that was already alerted prints `push skipped: already sent <stamp>`. APNs `410` deletes that device token from KV.

Do not create the namespace, the secret, or the deploy from an unattended agent. Those commands need your Cloudflare login.
