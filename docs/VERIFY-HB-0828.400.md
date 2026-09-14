# HB-0828.426 / 752 — verify (current-pack first paint + Share file)

**Tip** `cursor/mac-share-attach-1006` off `cursor/command-center-8b-3389`
**Stamp** `HB-0828.426  1.0 (752)` · bundle `com.corymurray.FulfillmentHeartbeat`
**No TestFlight until this PASSes.** HARD TF HOLD until **open shows today’s gold immediately** AND **Share attaches a report file** on **iPhone, iPad, and Mac**.

Soft FAIL 2026-09-14 work Mac:
1. Send opened native Apple Mail (`Hide My Email`) with **no attachment** — plaintext body only.
2. Work Mac has no usable Apple Mail account; Outlook / Teams / Files never saw a file.
3. Cold open / reopen painted week **202628 (~$113M)** then later swapped to week **202629 (~$26.4M)**.

This root holds splash until the current `current.sqlite` is on disk (or the fetch fails), then paints once. Share still prefers `UIActivityViewController` + PDF/PNG file URLs.

## CoS first — Mac Catalyst Share (over existing app)

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
./install-mac.sh
```

Force-quit Heartbeat (dock quit, don’t just close the window). Do not delete the app.

**Mac first paint Soft KEEP**
1. Dock-quit Heartbeat. Reopen.
2. Stay on the load screen until Command Center appears.
3. First gold must be **week 202629 / ~$26.4M** (today’s upload). Soft FAIL if **$113M / 202628** shows first, even briefly.
4. Do not tap Clear. Do not force-quit a second time.

**Mac Share Soft KEEP**
1. Share → pick page(s) → New Message.
2. Navy **Back** visible. **To** above the fold and typeable. Notes field present. Sheet resizable (+/−). Preview readable.
3. Attachment chip shows `Fulfillment-Heartbeat.pdf` (or page PNGs) — never missing.
4. Fill To → **Send**. System share sheet opens (Outlook / Teams / Files / AirDrop / Mail).
5. Pick **Outlook**. Draft shows the file chip. Send delivers the file. Soft FAIL if Apple Mail Hide My Email opens with plaintext and no attachment.

Must **compile**. Stay on Command Center. Do not open a section first.

| Check | Pass |
|---|---|
| Sidebar stamp | `HB-0828.426  1.0 (752)` |
| **First paint gold** | Open shows **$26.4M / week 202629** immediately. Never $113M / 202628 first. |
| **Share attachment** | New Message shows attachment chip. Send opens the **system share sheet** with `Fulfillment-Heartbeat.pdf` (or page PNGs). Outlook / Teams / Files / AirDrop receive the file. Never Apple Mail plaintext-only / Hide My Email with no attachment. |
| **Compile** | Mac Catalyst + iOS. No opaque-return / MainActor isolation FAIL. |
| **Dashboard-on-filter** | District / OM / Store / Clear: hero + glance rewrite the same turn. No Sales open+back. |
| **Section boxes (748)** | Open Sales after a filter: THIS WEEK / THIS SEAT already match. |
| **Clear identity** | District → Clear: company 2161 on dashboard and Sales. Not leftover 612. |
| Cool / LRU | ≤2 planes. No xlsx cook. No PulseCaches / expand on tap. |
| Automated test | `testArchitecture426FirstPaintIsCurrentPackGold` + `testArchitecture425MacShareAttachesReportViaShareSheet` KEEP |

## Soft KEEP

| KEEP | Status |
|---|---|
| First paint is current pack gold (no prior-week linger) | Soft KEEP this root |
| Share report file via system share sheet (PDF preferred / PNG pages) | Soft KEEP |
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

CoS + QC ship TestFlight. Do not upload TF from the agent.
