# HB-0828.428 / 754 — verify (Pick Path store expand shoppers)

**Tip** `cursor/mac-catalyst-category-70dd` off `cursor/mac-share-attach-1006` (`300eb83`)
**Stamp** `HB-0828.428  1.0 (754)` · bundle `com.corymurray.FulfillmentHeartbeat`
**752 Soft KEEP:** first-paint current pack gold + Share attach / `UIActivityViewController`.

Soft FAIL 2026-09-14: Mac Catalyst TestFlight upload of HB **752** rejected **ASC 90242** — Info.plist missing `LSApplicationCategoryType`. This root sets `public.app-category.business` in Heartbeat `Info.plist` and target `INFOPLIST_KEY_LSApplicationCategoryType` (`GENERATE_INFOPLIST_FILE = NO`).

## CoS first — Mac Catalyst archive + upload

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git checkout cursor/mac-catalyst-category-70dd
./install-mac.sh
```

Force-quit Heartbeat (dock quit, don’t just close the window). Do not delete the app.

Confirm the archived Mac Catalyst Info.plist has `LSApplicationCategoryType = public.app-category.business`, then **Product → Archive** (My Mac / Mac Catalyst) → upload to App Store Connect. Do not upload TF from the agent.

**Mac first paint Soft KEEP (752)**
1. Dock-quit Heartbeat. Reopen.
2. Stay on the load screen until Command Center appears.
3. First gold must be **week 202629 / ~$26.4M** (today’s upload). Soft FAIL if **$113M / 202628** shows first, even briefly.
4. Do not tap Clear. Do not force-quit a second time.

**Mac Share Soft KEEP (752)**
1. Share → pick page(s) → New Message.
2. Navy **Back** visible. **To** above the fold and typeable. Notes field present. Sheet resizable (+/−). Preview readable.
3. Attachment chip shows `Fulfillment-Heartbeat.pdf` (or page PNGs) — never missing.
4. Fill To → **Send**. System share sheet opens (Outlook / Teams / Files / AirDrop / Mail).
5. Pick **Outlook**. Draft shows the file chip. Send delivers the file. Soft FAIL if Apple Mail Hide My Email opens with plaintext and no attachment.

Must **compile**. Stay on Command Center. Do not open a section first.

| Check | Pass |
|---|---|
| Sidebar stamp | `HB-0828.428  1.0 (754)` |
| **ASC 90242** | Archived Mac Catalyst Info.plist has `LSApplicationCategoryType` = `public.app-category.business`. Upload is not rejected for missing category. |
| **First paint gold** | Open shows **$26.4M / week 202629** immediately. Never $113M / 202628 first. |
| **Share attachment** | New Message shows attachment chip. Send opens the **system share sheet** with `Fulfillment-Heartbeat.pdf` (or page PNGs). Outlook / Teams / Files / AirDrop receive the file. Never Apple Mail plaintext-only / Hide My Email with no attachment. |
| **Compile** | Mac Catalyst + iOS. No opaque-return / MainActor isolation FAIL. |
| **Dashboard-on-filter** | District / OM / Store / Clear: hero + glance rewrite the same turn. No Sales open+back. |
| **Section boxes (748)** | Open Sales after a filter: THIS WEEK / THIS SEAT already match. |
| **Clear identity** | District → Clear: company 2161 on dashboard and Sales. Not leftover 612. |
| Cool / LRU | ≤2 planes. No xlsx cook. No PulseCaches / expand on tap. |
| Automated test | `testArchitecture428PickPathStoreExpandListsJoinedShoppers` + `testArchitecture427MacCatalystHasAppCategory` + `testArchitecture426FirstPaintIsCurrentPackGold` KEEP |
| **Pick Path expand** | Open Pick Path → expand a store. Shopper / LDAP rows with readable Pick Path %, Avg PPH, Orders — not the pack-after-ready placeholder. Recook seat packs first. |

## Soft KEEP

| KEEP | Status |
|---|---|
| First paint is current pack gold (no prior-week linger) | Soft KEEP 752 |
| Share report file via system share sheet (PDF preferred / PNG pages) | Soft KEEP 752 |
| Readable preview, notes, resizable Mac sheet, Back, To above the fold | Soft KEEP |
| CC summaries rewrite with box maps; tiles bind stamp on MainActor | Soft KEEP |
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

CoS Mac-archives + uploads TestFlight. Do not upload TF from the agent.
