# How Heartbeat loads data

Source of truth: `Heartbeat Daily Report.xlsx` in the Supabase bucket `heartbeat-packs`.

You put that file on the server. Testers do not pick a file on the iPad.

On open:
1. If the on-device cache already has Labor and Picker, the app opens immediately.
2. If the cache is empty or incomplete, the app downloads the server workbook and builds the cache.
3. If the server workbook size changed, the app refreshes the cache in the background.
