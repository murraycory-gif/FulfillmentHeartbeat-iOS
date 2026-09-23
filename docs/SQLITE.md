# Heartbeat pack

The iPad is a **viewer**. GitHub Actions cooks `Heartbeat Daily Report.xlsx`
into `current.sqlite` and publishes it to Cloudflare R2, then upserts the
same bytes to Supabase Storage.

Download (primary): `https://pub-eafb309f53464d98902d12ac107f0f1e.r2.dev/current.sqlite`

Company seat key (same thin pack on this tip): `https://pub-eafb309f53464d98902d12ac107f0f1e.r2.dev/packs/seat/company/all/current.sqlite`

Supabase mirror (same file, for clients that still read the bucket):
`https://pcnjujfmlsklhrosxzlt.supabase.co/storage/v1/object/public/heartbeat-packs/current.sqlite`
and `packs/seat/company/all/current.sqlite` under that bucket.

The Daily Report workbook stays on Supabase Storage. `r2.dev` is rate-limited.
Swap `HBPackHost` in `FulfillmentHeartbeat/Info.plist` (and `PulseCloud.defaultPackHost`)
to a custom domain later. Cook stays on the weekday `*/15` schedule.

## How a filter works

Company-wide paints the cooked dashboard tiles.

District / division / store is a database lookup:

```
SELECT … FROM facts
WHERE section IN (sales, lostRevenue, labor, …)
  AND store_number IN (roster stores for this filter)
```

If store numbers in the sheet are padded (`0667` vs `667`), the lookup
retries the whole section and joins on aliases. The iPad does **not**
rebuild company math.

Labor loads on open. Picker shoppers load for the stores in the current
filter, then the full list when that page opens.

If a store is on the roster but the pack has no Loss Revenue row, the app
fills that store from `facts.json` (2,162 scored stores). Pack dollars always
win. District 03 is 20 NorCal stores totaling $36,193.

## Stamp

HB-0828.308 / 1.0 (630)
