# Heartbeat Supabase (one-time)

Project: `https://pcnjujfmlsklhrosxzlt.supabase.co`

## Create the bucket

1. Left sidebar → **Storage**.
2. **New bucket**.
3. Name: `heartbeat-packs`
4. Public bucket: **ON** (testers only need to download).
5. Create bucket.

## Allow the app to read and write

Still in Storage → heartbeat-packs → **Policies** → **New policy**:

- Policy name: `testers read pack`
- Allowed operation: **SELECT**
- Target roles: `anon`, `authenticated`
- USING expression: `true`

Add a second policy:

- Policy name: `publish pack`
- Allowed operations: **INSERT** and **UPDATE**
- Target roles: `anon`, `authenticated`
- WITH CHECK: `true`

If the UI has a template **Allow all access to everyone**, use that once instead.

## What the iPad does after this

- After you load a master workbook, the app uploads `current.sqlite`.
- On open, testers download that file. They do not pick Excel.
