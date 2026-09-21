#!/bin/sh
# Copy app Storage sources the kitchen compiles. No SwiftUI / HubLayout files.
# Workflow and local Mac cook must use this — no ad-hoc patches.
set -eu
ROOT="$(CDPATH= cd "$(dirname "$0")/../.." && pwd)"
INGEST="$ROOT/Tools/HeartbeatIngest"
mkdir -p "$INGEST/Sources"
cp "$ROOT/FulfillmentHeartbeat/Models/Domain.swift" "$INGEST/Sources/"
cp "$ROOT/FulfillmentHeartbeat/Storage/WorkbookParser.swift" "$INGEST/Sources/"
cp "$ROOT/FulfillmentHeartbeat/Storage/PulseSQLite.swift" "$INGEST/Sources/"
cp "$ROOT/FulfillmentHeartbeat/Storage/PulseCaches.swift" "$INGEST/Sources/"
cp "$ROOT/FulfillmentHeartbeat/Storage/PulseQuery.swift" "$INGEST/Sources/"
cp "$ROOT/FulfillmentHeartbeat/Storage/PulseLaunch.swift" "$INGEST/Sources/"
cp "$ROOT/FulfillmentHeartbeat/Storage/PulseSeatPack.swift" "$INGEST/Sources/"
cp "$ROOT/FulfillmentHeartbeat/BuildStamp.swift" "$INGEST/Sources/"
cp "$INGEST/Ingest.swift" "$INGEST/Sources/"
cp "$INGEST/RollupMarketFill.swift" "$INGEST/Sources/"
