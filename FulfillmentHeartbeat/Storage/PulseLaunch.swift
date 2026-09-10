import Foundation

/// Launch and refresh rules for the on-device SQLite pack.
/// Keep this off the network and off SwiftUI so the boot path can be tested.
enum PulseLaunch {
    static let minimumPackBytes = 50_000
    static let stagingFileName = "heartbeat-cloud.sqlite"
    static let bootDownloadTimeout: TimeInterval = 25
    /// Let the hub settle before expanding grains. Cards already painted.
    static let grainPaintDelayNanoseconds: UInt64 = 700_000_000
    /// Picker / item grains stay on disk until that page opens.
    static let loadPageOnlyOnReady = false

    /// Drop a paint or grain job when the user picked another filter.
    static func acceptPaint(generation: Int, current: Int, cancelled: Bool) -> Bool {
        !cancelled && generation == current
    }
    /// Cloud facts/pack after Who's looking — not on splash, not in the first breath.
    static let cloudHydrateDelayNanoseconds: UInt64 = 12_000_000_000
    static let foregroundCloudQuietSeconds: TimeInterval = 90

    static func shouldPullCloudOnForeground(secondsSinceReady: TimeInterval) -> Bool {
        secondsSinceReady >= foregroundCloudQuietSeconds
    }

    /// Skip another facts.json parse when the warehouse already has the store tables.
    static func shouldLoadPublishedFacts(lostStores: Int, salesStores: Int, minimum: Int = 200) -> Bool {
        lostStores < minimum && salesStores < minimum
    }

    static func fileBytes(at url: URL) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    }

    static func isUsableFileSize(_ bytes: Int) -> Bool {
        bytes >= minimumPackBytes
    }

    /// Leave the splash when a real pack is in memory, or when Excel store
    /// facts already painted dashboard cards (bundled or cloud).
    static func leaveSplash(localPackBytes: Int, loadedRows: Int, paintedStoreCards: Int = 0) -> Bool {
        if paintedStoreCards > 0 { return true }
        return isUsableFileSize(localPackBytes) && loadedRows > 0
    }

    static func usablePaintedCards(_ summaries: [SectionSummary]) -> Int {
        summaries.filter { $0.storeCount >= 8 || ($0.headline ?? 0) > 0 }.count
    }

    /// Fetch a remote pack only when the device has nothing usable, or the
    /// cloud file is a different size. A new app stamp must not force another
    /// download — that reloaded the pack on top of itself and jetsamed 4GB devices.
    static func shouldFetchRemotePack(remoteBytes: Int, localBytes: Int, localRowsLoaded: Int) -> Bool {
        guard isUsableFileSize(remoteBytes) else { return false }
        if localRowsLoaded > 0, localBytes == remoteBytes { return false }
        if localRowsLoaded == 0 { return true }
        return remoteBytes != localBytes
    }

    /// 4GB devices keep the in-memory pack. Swap the file for the next launch
    /// instead of reading current.sqlite a second time.
    static func reloadInSessionAfterFetch(constrained: Bool, localRowsLoaded: Int) -> Bool {
        if constrained, localRowsLoaded > 0 { return false }
        return true
    }

    static func missingPackMessage() -> String {
        "No Heartbeat pack is on this device, and the cloud pack did not load. Check the network and tap Try again."
    }
}
