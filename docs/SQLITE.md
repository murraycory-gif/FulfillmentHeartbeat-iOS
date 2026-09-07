# Heartbeat on-device database

TestFlight freeze: **1.0 (473) / HB-0828.102** tagged `tf-1.0.473`.
Database work starts at **1.0 (474) / HB-0828.103**.

## What this build does

After a successful master Excel load, the app writes `heartbeat.sqlite` next to the old JSON snapshot.

On the next launch it prefers that SQLite pack if it has rows.

Excel is still how a new day enters the app. SQLite is the working copy.

## What Cory does next

1. Pull and install on the 12-inch iPad (not TestFlight testers yet):

```bash
cd ~/Developer/FulfillmentHeartbeat-iOS
git pull origin main
DEVICE_UDID=676FA816-88AE-59D9-A89D-5C17BFC2DA96 ./install-ipad.sh
```

2. Confirm sidebar stamp **HB-0828.103  1.0 (474)**.
3. Upload the same master workbook once.
4. Wait for 15 of 15, pick Who's looking, confirm dashboard numbers match 473.
5. Force-quit Heartbeat and open it again. Data should return without choosing Excel.

Do **not** push 474 to TestFlight until that loop is clean.

## Still to build

- Split `facts` into per-scorecard tables (`sales`, `labor`, `pickers`, `presub_items`).
- Pages query SQLite instead of holding every row in RAM.
- A “Load database pack” button so testers skip OneDrive xlsx.
- Optional iCloud folder for the `.sqlite` pack.

## Do not change for testers

Keep TestFlight on **473** until the iPad loop above is signed off.
