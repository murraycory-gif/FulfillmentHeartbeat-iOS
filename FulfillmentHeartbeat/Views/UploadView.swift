import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct UploadView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @State private var exportItem: ExportItem?
    @State private var showStatus = false
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upload workbooks")
                        .font(.largeTitle.weight(.semibold))
                    Text("Download the Excel from Power BI, tap Choose file, pick it from iCloud Drive or OneDrive.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
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
                    }
                }

                Text("Headers can be flexible — Division, Operations OM, and Store Number are picked up automatically. Use Link to pull the raw Power BI export.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
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

    private func beginImport(_ section: MetricSection) {
        HeartbeatFilePicker.shared.present { data, name in
            store.importWorkbook(data: data, filename: name, section: section)
        } onFail: { message in
            store.errorMessage = message
        }
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
                        Text(section.title)
                            .font(.title3.weight(.bold))
                        Text(section.blurb)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(section == .pickPathPicker
                             ? "Shows pickers under each store on Pick Path"
                             : "Updates the \(section.short) card on the dashboard")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.blue)
                    }
                    Spacer(minLength: 0)
                }

                Text("Expects \(section.expectedMetrics)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)

                Button(action: onPick) {
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppTheme.blue)
                        Text("Choose file from iCloud or OneDrive")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        Text(".xlsx or .csv · replaces current \(section.short) data")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("Choose file")
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
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer(minLength: 0)
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

                UpdatedStamp(date: upload?.uploadedAt, wide: true)
            }
        }
    }
}

/// Copies the picked file into the app first. iCloud Drive and OneDrive are
/// not readable in-place after the picker closes.
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
