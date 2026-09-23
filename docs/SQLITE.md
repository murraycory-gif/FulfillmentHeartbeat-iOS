# Heartbeat pack

The iPad is a **viewer**. GitHub Actions cooks `Heartbeat Daily Report.xlsx`
into `current.sqlite` plus **seat packs** and publishes them to `heartbeat-packs`.

See [SEAT-SCOPED-PACKS.md](SEAT-SCOPED-PACKS.md) for the Tip 1 contract.

## Layout

```
current.sqlite                         # LIVE root. Company seat (~21MB) when market ~56MB exceeds Storage ~50MB.
packs/manifest.json
packs/seat/company/all/current.sqlite  # thin company summary (also copied to root when market is over the limit)
packs/seat/district/03/current.sqlite
packs/seat/om/Jino-Arvin/current.sqlite
packs/seat/store/12/current.sqlite
```

Under a seat the hub paints from **that** sqlite only. Market
`current.sqlite` is not the primary. `applySeatSlice` of the full market
is banned.

District 03 is 20 NorCal stores. Every section Stores N = 20.

## Stamp

HB-0828.471 / 1.0 (787) — iPad ScoreCard columns fill the card evenly. 468 KEEP: Live Sales come from current.sqlite (store 68 week 202630 Sunday $14,454.90). facts.json is not a live source. Cook deletes facts.json. An on-device week older than the pack week is cleared and redownloaded. 467 KEEP: BY DAY uses payload keys only. Shoppers on Store / Ops / District / Division. Denser section spacing. 465 KEEP: Pages tap paints the destination before roster walks and before hidden Dashboard / scorecard teardown. 463 KEEP: THIS SEAT callout removed on every page and filter. Company seat cap 40MB. 436 KEEP: Pick Path expand shoppers + Prep Store chrome.
