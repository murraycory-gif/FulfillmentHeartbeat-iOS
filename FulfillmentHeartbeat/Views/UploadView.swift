import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct UploadView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showImporter = false
    @State private var importTarget: MetricSection?
    @State private var masterImport = false
    @State private var exportItem: ExportItem?
    @State private var showStatus = false
    @State private var showError = false
    @State private var pageWidth: CGFloat = 900

    var body: some View {
        VStack(spacing: 0) {
            if sizeClass == .regular {
                HubStickyPageBanner(
                    icon: HubDestination.upload.symbol,
                    title: "Upload Workbooks",
                    accessory: store.isImporting ? (store.importLabel ?? "Loading…") : store.filters.summary
                )
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MasterLoadPanel(
                        enabled: !store.isImporting,
                        importing: store.isImporting && importTarget == nil,
                        label: store.importLabel,
                        linkedName: store.linkedMasterName,
                        lastLoaded: store.linkedMasterLoadedAt,
                        onReload: { store.reloadLinkedMaster() },
                        onPick: beginMasterImport,
                        onUnlink: { store.unlinkMasterFile() }
                    )
                    HubBanner(
                        icon: "square.and.arrow.up",
                        title: "Or Add Individual KPI Data"
                    )

                    LazyVGrid(columns: uploadColumns, spacing: 16) {
                        ForEach(MetricSection.uploadOrder) { section in
                            UploadPanel(
                                section: section,
                                upload: store.upload(for: section),
                                justUpdated: store.lastImportedSection == section,
                                enabled: !store.isImporting,
                                onPick: { beginImport(section) },
                                onTemplate: {
                                    exportItem = ExportItem(
                                        filename: "\(section.rawValue)-template.csv",
                                        data: Data(SampleMarket.templateCSV(for: section).utf8)
                                    )
                                },
                                onClear: { store.clearSection(section) }
                            )
                            .frame(maxWidth: .infinity, minHeight: pageWidth < 700 ? 260 : 428, maxHeight: .infinity, alignment: .top)
                        }
                    }

                    Text("Master load reads every sheet in one .xlsx. Name the tabs Lost Revenue, MI, 5 Star, Pre-Sub OOS, Pre-Sub OOS Item, Pick Path, Path Picker, Aisle Mapper, Prep, Dynacap, Schedule, PPH, Labor, and Picker ScoreCard — or leave the Power BI headers and we will map them. Individual cards still replace one KPI at a time.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .readWidth($pageWidth)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: Self.workbookTypes,
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .fileExporter(
            isPresented: Binding(
                get: { exportItem != nil },
                set: { if !$0 { exportItem = nil } }
            ),
            document: exportItem ?? ExportItem(filename: "template.csv", data: Data()),
            contentType: .commaSeparatedText,
            defaultFilename: exportItem?.filename ?? "template.csv"
        ) { _ in
            exportItem = nil
        }
        .alert("Dashboard updated", isPresented: $showStatus) {
            Button("View dashboard") {
                store.statusMessage = nil
                router.open(.dashboard)
            }
            Button("OK", role: .cancel) {
                store.statusMessage = nil
            }
        } message: {
            Text(store.statusMessage ?? "")
        }
        .alert("Couldn’t import", isPresented: $showError) {
            Button("OK", role: .cancel) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: store.statusMessage) { _, message in
            if store.needsRolePick {
                showStatus = false
                return
            }
            showStatus = message != nil
        }
        .onChange(of: store.errorMessage) { _, message in
            showError = message != nil
        }
        .onChange(of: showStatus) { _, presented in
            if !presented { store.statusMessage = nil }
        }
        .onChange(of: showError) { _, presented in
            if !presented { store.errorMessage = nil }
        }
    }

    private var uploadColumns: [GridItem] {
        HubLayout.grid(HubLayout.uploadColumns(width: pageWidth, sizeClass: sizeClass), spacing: 16)
    }

    private func beginMasterImport() {
        importTarget = nil
        masterImport = true
        HeartbeatFilePicker.shared.present { data, name in
            store.importMasterWorkbook(data: data, filename: name)
        } onFail: { message in
            store.errorMessage = message
        }
    }

    private func beginImport(_ section: MetricSection) {
        importTarget = section
        masterImport = false
        HeartbeatFilePicker.shared.present { data, name in
            store.importWorkbook(data: data, filename: name, section: section)
        } onFail: { message in
            store.errorMessage = message
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        let section = importTarget
        let master = masterImport
        importTarget = nil
        masterImport = false
        showImporter = false
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let file = try HeartbeatFilePicker.readPickedFile(url)
                if master || section == nil {
                    store.importMasterWorkbook(data: file.data, filename: file.name, sourceURL: url)
                } else if let section {
                    store.importWorkbook(data: file.data, filename: file.name, section: section)
                }
            } catch {
                store.errorMessage = error.localizedDescription
            }
        case .failure(let error):
            store.errorMessage = error.localizedDescription
        }
    }
    private static var workbookTypes: [UTType] {
        var types: [UTType] = [.item, .data, .commaSeparatedText, .spreadsheet]
        if let xlsx = UTType(filenameExtension: "xlsx") { types.insert(xlsx, at: 0) }
        if let csv = UTType(filenameExtension: "csv") { types.append(csv) }
        return types
    }
}


struct MasterLoadPanel: View {
    var enabled: Bool
    var importing: Bool
    var label: String?
    var linkedName: String?
    var lastLoaded: Date?
    var onReload: () -> Void
    var onPick: () -> Void
    var onUnlink: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HubBanner(
                icon: "square.stack.3d.up.fill",
                title: "Master load",
                accessory: linkedName.map { "Linked  ·  \($0)" } ?? "One shared .xlsx  ·  every sheet  ·  every scorecard",
                clipped: false
            )
            VStack(alignment: .leading, spacing: 14) {
                Text(linkedName == nil
                     ? "On a work iPad, Choose from iCloud Drive — not OneDrive. Company OneDrive encrypts the file for unmanaged apps. Save the workbook to iCloud once, pick that copy, then Reload."
                     : "Reload the linked iCloud file. Work OneDrive is blocked by Intune until IT allows Heartbeat (com.corymurray.FulfillmentHeartbeat).")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                if linkedName != nil {
                    Button(action: onReload) {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise.icloud.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(AppTheme.blue)
                            Text(importing ? (label ?? "Reloading master workbook…") : "Reload shared file")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(reloadCaption)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textTertiary)
                            Text(importing ? "Loading" : "Reload")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(AppTheme.blue, in: Capsule(style: .continuous))
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                                .fill(AppTheme.blueSoft)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                                .strokeBorder(AppTheme.blue.opacity(0.35), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }

                Button(action: onPick) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up.on.square")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(linkedName == nil ? "Choose the shared master file" : "Choose a different file")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(".xlsx with a sheet for each KPI")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        Spacer(minLength: 0)
                        Text("Choose file")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.blue, in: Capsule(style: .continuous))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                            .fill(linkedName == nil ? AppTheme.blueSoft : AppTheme.bg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                            .strokeBorder(AppTheme.blue.opacity(0.28), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!enabled)

                if linkedName != nil {
                    Button("Unlink shared file", action: onUnlink)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.bad)
                        .disabled(!enabled)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.tableFill)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 2.5)
        )
    }

    private var reloadCaption: String {
        if let lastLoaded {
            return "Last loaded \(HeartbeatFormat.updated(lastLoaded))  ·  pulls the latest export"
        }
        return "Pulls the latest export from the linked file"
    }
}

struct UploadPanel: View {
    let section: MetricSection
    let upload: UploadRecord?
    var justUpdated: Bool = false
    var enabled: Bool = true
    let onPick: () -> Void
    let onTemplate: () -> Void
    let onClear: () -> Void

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: section.symbol)
                        .font(.title3)
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        panelTitle
                        Text(section.blurb)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                            .frame(minHeight: 32, alignment: .topLeading)
                        Text(section == .pickPathPicker
                             ? "Shows pickers under each store on Pick Path"
                             : "Updates the \(section.short) card on the dashboard")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.blue)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }

                Text("Expects \(section.expectedMetrics)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(2)
                    .frame(minHeight: 32, alignment: .topLeading)

                Button(action: onPick) {
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppTheme.blue)
                        Text("Choose file from iCloud or OneDrive")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                            .multilineTextAlignment(.center)
                        Text(".xlsx or .csv · replaces current \(section.short) data")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text("Choose file")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.blue, in: Capsule(style: .continuous))
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, minHeight: 148)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                            .fill(justUpdated ? AppTheme.blueSoft : AppTheme.bg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                            .strokeBorder(AppTheme.blue.opacity(0.22), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!enabled)

                HStack(alignment: .center, spacing: 10) {
                    if let upload {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(upload.filename)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text("\(upload.rowCount) rows")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            if let validation = upload.validation, !validation.isEmpty {
                                Text(validation)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("No file loaded")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let source = section.sourceLink {
                        Button("Link") {
                            UIApplication.shared.open(source)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else {
                        Button("Template", action: onTemplate)
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    if upload != nil {
                        Button("Clear", action: onClear)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.bad)
                    }
                }
                .frame(minHeight: 52, alignment: .center)

                Spacer(minLength: 0)

                UpdatedStamp(date: upload?.uploadedAt, wide: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var panelTitle: some View {
        if section == .lostRevenue {
            (Text("Loss Revenue ") + Text("ScoreCard").foregroundStyle(AppTheme.blue))
                .font(.title3.weight(.bold))
        } else if section == .missingItems {
            (Text("Missing Items ") + Text("ScoreCard").foregroundStyle(AppTheme.blue))
                .font(.title3.weight(.bold))
        } else if section == .preSubOOS {
            (Text("Pre-Sub OOS ") + Text("ScoreCard").foregroundStyle(AppTheme.blue))
                .font(.title3.weight(.bold))
        } else if section == .aisleMapper {
            Text("Aisle Mapper")
                .font(.title3.weight(.bold))
        } else if section == .preSubOOSItem {
            (Text("Pre-Sub OOS ") + Text("Item").foregroundStyle(AppTheme.blue))
                .font(.title3.weight(.bold))
        } else {
            Text(section.title)
                .font(.title3.weight(.bold))
        }
    }
}

struct ShareImportSheet: View {
    let section: MetricSection
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import \(section.title)")
                .font(.title2.weight(.bold))
            Text("On this iPad, Apple’s file picker crashes when it opens these Power BI Excel files. Share the file from Files instead — that does not crash.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Tap Open Files")
                Text("2. Go to iCloud Drive or OneDrive")
                Text("3. Tap the Excel → Share → Heartbeat")
            }
            .font(.body.weight(.medium))
            Button {
                if let url = URL(string: "shareddocuments://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Files")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.blue, in: Capsule())
            }
            .buttonStyle(.plain)
            Button("Cancel") {
                store.waitingForFileSection = nil
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(minWidth: 480, minHeight: 360)
        .background(AppTheme.bg)
        .onChange(of: store.isImporting) { _, importing in
            if importing { dismiss() }
        }
        .onChange(of: store.statusMessage) { _, message in
            if message != nil { dismiss() }
        }
    }
}

/// Copies iCloud / OneDrive files into memory. Not used as a picker.
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

        var lastRaw: Data?
        for raw in blobs {
            lastRaw = raw
            if let ready = usableWorkbook(raw) { return (ready, name) }
            let stripped = WorkbookParser.stripWrapper(raw)
            if stripped.starts(with: [0x50, 0x4B, 0x03, 0x04]) { return (stripped, name) }
        }

        let sample = lastRaw ?? Data()
        let head = sample.prefix(8).map { String(format: "%02X", $0) }.joined(separator: " ")
        let eocd = ZipArchive.findEOCD(sample) != nil
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

struct ExportItem: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var filename: String
    var data: Data

    init(filename: String, data: Data) {
        self.filename = filename
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        filename = "template.csv"
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    UploadView()
        .environmentObject(HeartbeatStore())
        .environmentObject(HubRouter())
}
