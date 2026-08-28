import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct UploadView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @State private var showImporter = false
    @State private var importTarget: MetricSection?
    @State private var masterImport = false
    @State private var exportItem: ExportItem?
    @State private var showStatus = false
    @State private var showError = false
    @State private var pageWidth: CGFloat = 900

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HubBanner(
                    icon: HubDestination.upload.symbol,
                    title: "Upload Workbooks",
                    accessory: store.isImporting ? (store.importLabel ?? "Loading…") : store.filters.summary
                )
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
                        .frame(maxWidth: .infinity, minHeight: 428, maxHeight: .infinity, alignment: .top)
                    }
                }

                Text("Master load reads every sheet in one .xlsx. Name the tabs Lost Revenue, MI, 5 Star, Pick Path, Path Picker, Aisle Mapper, Prep, Dynacap, Schedule, PPH, Labor, and Picker ScoreCard — or leave the Power BI headers and we will map them. Individual cards still replace one KPI at a time.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(20)
            .readWidth($pageWidth)
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
        HubLayout.grid(HubLayout.uploadColumns(width: pageWidth), spacing: 16)
    }

    private func beginMasterImport() {
        importTarget = nil
        masterImport = true
        showImporter = true
    }

    private func beginImport(_ section: MetricSection) {
        importTarget = section
        masterImport = false
        showImporter = true
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
                     ? "Choose the shared workbook once from iCloud or OneDrive. After that, Reload pulls the latest from that same file."
                     : "Reload grabs the latest from the linked iCloud or OneDrive file. Choose file still lets you pick a different workbook.")
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
        } else if section == .aisleMapper {
            Text("Aisle Mapper")
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
            forOpeningContentTypes: [.item, .data, .commaSeparatedText],
            asCopy: true
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
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        if FileManager.default.isUbiquitousItem(at: url) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            let deadline = Date().addingTimeInterval(20)
            while Date() < deadline {
                let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .fileSizeKey])
                let status = values?.ubiquitousItemDownloadingStatus
                if status == .current || status == .downloaded { break }
                if let size = values?.fileSize, size > 0, status != .notDownloaded { break }
                Thread.sleep(forTimeInterval: 0.15)
            }
        }

        var copied: Data?
        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [.forUploading], error: &coordError) { local in
            copied = try? Data(contentsOf: local, options: [.uncached])
        }
        if copied == nil || copied?.isEmpty == true {
            copied = try Data(contentsOf: url, options: [.uncached])
        }
        guard let raw = copied, !raw.isEmpty else {
            throw NSError(
                domain: "HeartbeatImport",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not read that file. Open it in Files first so iCloud or OneDrive finishes downloading, then Choose file again."]
            )
        }
        var owned = Data()
        owned.append(contentsOf: raw)
        return (owned, url.lastPathComponent)
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
