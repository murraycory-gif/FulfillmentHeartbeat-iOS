# Heartbeat pack

The iPad is a **viewer**. GitHub Actions cooks `Heartbeat Daily Report.xlsx`
into `current.sqlite` and publishes it to the `heartbeat-packs` bucket.

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

HB-0828.316 / 1.0 (638)
