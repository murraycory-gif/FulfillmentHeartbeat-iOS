# How Heartbeat loads data

Power BI Mobile, Amazon, and every serious ops app do the same thing:

1. Heavy files are ingested **off the phone**.
2. The phone stores a local SQLite cache.
3. Open reads that cache. No Excel parse on launch.

Heartbeat now follows that.

## Daily publish (you, once)

1. Export `Heartbeat Daily Report.xlsx` from Power BI.
2. On **your** iPad or Mac Heartbeat, Upload that file **once**.
3. The app writes `heartbeat.sqlite` and uploads `current.sqlite` to the `heartbeat-packs` bucket.

Or from the Mac after a good load:

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
DEVICE_UDID=676FA816-88AE-59D9-A89D-5C17BFC2DA96 ./publish-pack.sh
```

## Testers

Open the app. Data comes from `current.sqlite`. They never pick Excel.

If Labor or Picker are empty, the published pack is stale. Publish again after a full Upload on your device.
