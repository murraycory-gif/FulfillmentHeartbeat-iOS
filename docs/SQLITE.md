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

HB-0828.407 / 1.0 (733) — Phone THIS SEAT chips use hero + `dashboardTableValues` pack keys. False-zero ban: Pick Path Exceptions = total−compliant; Prep Not Ready derives from `pnr_rate_pct`; Picker Shoppers/Opportunity/Doing Well from chrome; Labor Weeks from pack `week`. Dynacap Util % and Schedule Over/Under keep `utilization_pct` / `over_scheduled` / `under_scheduled`. Phone density Soft KEEP (compact cards + header, one vertical ScrollView, no remount). Share Mail Soft KEEP (730) and Jetsam expand gates unchanged.
