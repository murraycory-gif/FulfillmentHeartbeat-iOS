# How Heartbeat loads data (Amazon-style)

Amazon does not parse catalogs on the phone. It opens a local cache, then refreshes from a ready server file.

Heartbeat now:

1. Opens `heartbeat.sqlite` on the device if Labor and Picker are in it.
2. If that cache is incomplete, downloads `current.sqlite` from Supabase.
3. If that pack is also missing Labor or Picker, downloads `Heartbeat Daily Report.xlsx` once, builds the cache, and publishes a **complete** `current.sqlite`.
4. Later opens are cache-only until the server workbook size changes.

Incomplete packs are never published. That was why Labor and Picker vanished after a fast launch.
