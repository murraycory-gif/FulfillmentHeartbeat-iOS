#!/bin/sh
# Retired. Heartbeat no longer reads or writes Supabase Storage.
# Cooks publish only to Cloudflare R2. This script stays so an old call
# does not contact the project (quota-blocked through Oct 7 2026) and
# does not fail the publish.
set -eu
echo "Supabase publishing is retired. Not contacting Supabase."
exit 0
