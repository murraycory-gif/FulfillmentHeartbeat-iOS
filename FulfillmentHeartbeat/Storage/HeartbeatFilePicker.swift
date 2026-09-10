import UIKit
import UniformTypeIdentifiers

/// Copies iCloud / OneDrive / Files drops into memory. Not an Upload page.
final class HeartbeatFilePicker: NSObject, UIDocumentPickerDelegate {
    static let shared = HeartbeatFilePicker()
    private var onPick: ((Data, String) -> Void)?
    private var onFail: ((String) -> Void)?

    func present(onPick: @escaping (Data, String) -> Void, onFail: @escaping (String) -> Void) {
        self.onPick = onPick
        self.onFail = onFail
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [
                UTType(filenameExtension: "xlsx") ?? .spreadsheet,
                UTType(filenameExtension: "xlsm") ?? .spreadsheet,
                .spreadsheet,
                .commaSeparatedText,
                .item,
                .data,
            ],
            asCopy: false
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.modalPresentationStyle = .formSheet
        picker.preferredContentSize = CGSize(width: 720, height: 640)
        guard let presenter = Self.topController() else {
            onFail("Could not open the file picker.")
            return
        }
        if presenter.presentedViewController != nil {
            presenter.dismiss(animated: false) {
                presenter.present(picker, animated: true)
            }
        } else {
            presenter.present(picker, animated: true)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            onFail?("No file was selected.")
            clear()
            return
        }
        let success = onPick
        let fail = onFail
        clear()
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let file = try Self.readPickedFile(url)
                DispatchQueue.main.async { success?(file.data, file.name) }
            } catch {
                DispatchQueue.main.async { fail?(error.localizedDescription) }
            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        clear()
    }

    static func readPickedFile(_ url: URL) throws -> (data: Data, name: String) {
        let name = url.lastPathComponent
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        if FileManager.default.isUbiquitousItem(at: url) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }

        var blobs: [Data] = []
        if let doc = readUIDocument(url) { blobs.append(doc) }
        if let exported = exportSpreadsheet(from: url) { blobs.append(exported) }
        if let coordinated = coordinatedBytes(url, forUploading: false) { blobs.append(coordinated) }
        if let uploaded = coordinatedBytes(url, forUploading: true) { blobs.append(uploaded) }
        if FileManager.default.fileExists(atPath: url.path),
           let direct = try? Data(contentsOf: url, options: [.uncached]) {
            blobs.append(direct)
        }

        for raw in blobs {
            if let ready = usableWorkbook(raw) { return (ready, name) }
            let stripped = WorkbookParser.stripWrapper(raw)
            if stripped.starts(with: [0x50, 0x4B, 0x03, 0x04]) { return (stripped, name) }
        }

        throw importError("Work OneDrive encrypted this workbook (Intune). Save it to iCloud Drive from Excel, then Choose that iCloud file.")
    }

    private static func readUIDocument(_ url: URL) -> Data? {
        guard !Thread.isMainThread else { return nil }
        let dest = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HeartbeatImports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        let copy = dest.appendingPathComponent(UUID().uuidString + ".xlsx")
        try? FileManager.default.copyItem(at: url, to: copy)
        let fileURL = FileManager.default.fileExists(atPath: copy.path) ? copy : url
        let lock = DispatchSemaphore(value: 0)
        var data: Data?
        DispatchQueue.main.async {
            let doc = HeartbeatXlsxDocument(fileURL: fileURL)
            doc.open { ok in
                if ok { data = doc.fileData }
                doc.close { _ in
                    if fileURL == copy { try? FileManager.default.removeItem(at: copy) }
                    lock.signal()
                }
            }
        }
        _ = lock.wait(timeout: .now() + 45)
        return (data?.count ?? 0) > 64 ? data : nil
    }

    private static func coordinatedBytes(_ url: URL, forUploading: Bool) -> Data? {
        var data: Data?
        var coordError: NSError?
        let options: NSFileCoordinator.ReadingOptions = forUploading ? [.forUploading] : []
        NSFileCoordinator().coordinate(readingItemAt: url, options: options, error: &coordError) { local in
            data = try? Data(contentsOf: local, options: [.uncached])
        }
        return (data?.count ?? 0) > 64 ? data : nil
    }

    private static func usableWorkbook(_ data: Data) -> Data? {
        let unzipped = WorkbookParser.stripWrapper(data)
        if let extracted = WorkbookParser.extractZipPayload(unzipped) { return extracted }
        if unzipped.starts(with: [0x50, 0x4B]) { return unzipped }
        let unwrapped = unwrapWorkbook(unzipped)
        if unwrapped.starts(with: [0x50, 0x4B]) { return unwrapped }
        if looksLikeText(unwrapped) { return unwrapped }
        if unzipped.count > 100_000 { return unzipped }
        return nil
    }

    private static func exportSpreadsheet(from url: URL) -> Data? {
        guard let provider = NSItemProvider(contentsOf: url) else { return nil }
        let typeIds = [
            "org.openxmlformats.spreadsheetml.sheet",
            "com.microsoft.excel.xlsx",
            "com.microsoft.office.openxml.spreadsheetml.sheet",
            UTType.spreadsheet.identifier,
            UTType.data.identifier,
        ]
        for typeId in typeIds {
            if let data = loadProviderData(provider, typeId: typeId), data.count > 64 {
                return data
            }
        }
        return nil
    }

    private static func loadProviderData(_ provider: NSItemProvider, typeId: String) -> Data? {
        let lock = DispatchSemaphore(value: 0)
        var result: Data?
        if provider.hasItemConformingToTypeIdentifier(typeId) {
            provider.loadFileRepresentation(forTypeIdentifier: typeId) { file, _ in
                if let file { result = try? Data(contentsOf: file, options: [.uncached]) }
                lock.signal()
            }
            _ = lock.wait(timeout: .now() + 40)
            if let result, result.count > 64 { return result }
        }
        provider.loadDataRepresentation(forTypeIdentifier: typeId) { data, _ in
            result = data
            lock.signal()
        }
        _ = lock.wait(timeout: .now() + 40)
        return result
    }

    private static func unwrapWorkbook(_ data: Data) -> Data {
        if let opened = openXlsx(data) { return opened }
        if let sliced = scanForZip(data), let opened = openXlsx(sliced) { return opened }
        for offset in [4, 8, 512, 1024, 4096, 4099, 4100, 8192] where offset < data.count - 64 {
            let slice = data.subdata(in: offset..<data.count)
            if let opened = openXlsx(slice) { return opened }
        }
        return data
    }

    private static func openXlsx(_ data: Data) -> Data? {
        guard data.starts(with: [0x50, 0x4B]), let zip = ZipArchive(data: data) else { return nil }
        if zip.file(named: "xl/workbook.xml") != nil { return data }
        let nested = zip.entryNames()
            .filter { name in
                let lower = name.lowercased()
                return lower.hasSuffix(".xlsx") || lower.hasSuffix(".xlsm") || lower.hasSuffix(".csv")
            }
            .compactMap { zip.file(named: $0) }
            .max(by: { $0.count < $1.count })
        if let nested {
            if nested.starts(with: [0x50, 0x4B]), ZipArchive(data: nested)?.file(named: "xl/workbook.xml") != nil {
                return nested
            }
            if looksLikeText(nested) { return nested }
        }
        return nil
    }

    private static func scanForZip(_ data: Data) -> Data? {
        let sig = Data([0x50, 0x4B, 0x03, 0x04])
        var start = data.startIndex
        var attempts = 0
        let windowEnd = data.index(data.startIndex, offsetBy: min(data.count, 131_072))
        while attempts < 12, let hit = data.range(of: sig, in: start..<windowEnd) {
            let sliced = data.subdata(in: hit.lowerBound..<data.endIndex)
            if openXlsx(sliced) != nil { return sliced }
            start = data.index(after: hit.lowerBound)
            attempts += 1
        }
        if let hit = data.range(of: sig) {
            let sliced = data.subdata(in: hit.lowerBound..<data.endIndex)
            if openXlsx(sliced) != nil { return sliced }
            return sliced
        }
        return nil
    }

    private static func importError(_ message: String) -> NSError {
        NSError(domain: "HeartbeatImport", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func looksLikeText(_ data: Data) -> Bool {
        guard let sample = String(data: data.prefix(200), encoding: .utf8) else { return false }
        return sample.contains(",") || sample.contains("\t")
    }

    private func clear() {
        onPick = nil
        onFail = nil
    }

    private static func topController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}

final class HeartbeatXlsxDocument: UIDocument {
    var fileData: Data?

    override func contents(forType typeName: String) throws -> Any {
        fileData ?? Data()
    }

    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        fileData = contents as? Data
    }
}
