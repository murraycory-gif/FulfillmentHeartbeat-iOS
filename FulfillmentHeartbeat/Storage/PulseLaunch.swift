import Foundation

/// Launch and refresh rules for the on-device SQLite pack.
/// Keep this off the network and off SwiftUI so the boot path can be tested.
enum PulseLaunch {
    static let minimumPackBytes = 50_000
    static let stagingFileName = "heartbeat-cloud.sqlite"
    static let bootDownloadTimeout: TimeInterval = 25

    static func fileBytes(at url: URL) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    }

    static func isUsableFileSize(_ bytes: Int) -> Bool {
        bytes >= minimumPackBytes
    }

    /// Leave the splash only when rows from a real pack are already in memory.
    static func leaveSplash(localPackBytes: Int, loadedRows: Int) -> Bool {
        isUsableFileSize(localPackBytes) && loadedRows > 0
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
        "No Heartbeat pack is on this device, and the cloud pack did not load. Check the network and tap Try again. On iPad you can also upload Heartbeat Daily Report from Settings."
    }
}
