# Heartbeat pack

The iPad is a **viewer**. GitHub Actions cooks `Heartbeat Daily Report.xlsx`
into `current.sqlite` plus **seat packs** and publishes them to `heartbeat-packs`.

See [SEAT-SCOPED-PACKS.md](SEAT-SCOPED-PACKS.md) for the Tip 1 contract.

## Layout

```
current.sqlite                         # market — Who’s looking roster + Clear
packs/manifest.json
packs/seat/company/all/current.sqlite  # thin company summary
packs/seat/district/03/current.sqlite
packs/seat/om/Jino-Arvin/current.sqlite
packs/seat/store/12/current.sqlite
```

Under a seat the hub paints from **that** sqlite only. Market
`current.sqlite` is not the primary. `applySeatSlice` of the full market
is banned.

District 03 is 20 NorCal stores. Every section Stores N = 20.

## Stamp

HB-0828.390 / 1.0 (716) — iPhone Picker cards; first-tap Pages; 44pt hits; Assist ops-coach shape; hide Unassigned Markets; roster-gate identities; Labor Total banner only when TVA/Total missing. Recook + republish still required for OM people packs.
