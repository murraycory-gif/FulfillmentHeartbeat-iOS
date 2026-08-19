import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct UploadView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @State private var showImporter = false
    @State private var importTarget: MetricSection?
    @State private var exportItem: ExportItem?
    @State private var showStatus = false
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upload workbooks")
                        .font(.largeTitle.weight(.semibold))
                    Text("One Excel file for each section. That file replaces the matching card on the dashboard.")
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
                            onDropURL: { store.importWorkbook(url: $0, section: section) },
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

                Text("Headers can be flexible — Division, Operations OM, and Store Number are picked up automatically. Use Link to pull the raw Power BI export, or Template for a clean file.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(20)
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

    private func beginImport(_ section: MetricSection) {
        importTarget = section
        showImporter = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        let section = importTarget
        importTarget = nil
        switch result {
        case .success(let urls):
            guard let section, let url = urls.first else {
                showImporter = false
                return
            }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent
                showImporter = false
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    store.importWorkbook(data: data, filename: filename, section: section)
                }
            } catch {
                showImporter = false
                store.errorMessage = error.localizedDescription
            }
        case .failure(let error):
            showImporter = false
            store.errorMessage = error.localizedDescription
        }
    }

    private static var workbookTypes: [UTType] {
        var types: [UTType] = [.commaSeparatedText, .plainText, .spreadsheet, .data]
        if let xlsx = UTType(filenameExtension: "xlsx") { types.insert(xlsx, at: 0) }
        if let xls = UTType(filenameExtension: "xls") { types.insert(xls, at: 1) }
        if let csv = UTType(filenameExtension: "csv") { types.append(csv) }
        return types
    }
}

struct UploadPanel: View {
    let section: MetricSection
    let upload: UploadRecord?
    var justUpdated: Bool = false
    var enabled: Bool = true
    let onPick: () -> Void
    let onDropURL: (URL) -> Void
    let onTemplate: () -> Void
    let onClear: () -> Void

    @State private var targeted = false

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

                dropZone

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

    private var dropZone: some View {
        Button(action: onPick) {
            VStack(spacing: 8) {
                Image(systemName: targeted ? "tray.and.arrow.down.fill" : "square.and.arrow.up")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.blue)
                Text(targeted ? "Drop to replace this section" : "Drop Excel here or choose a file")
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
                    .fill(targeted || justUpdated ? AppTheme.blueSoft : AppTheme.bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                    .strokeBorder(AppTheme.blue.opacity(targeted ? 0.7 : 0.22), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onDrop(of: Self.dropTypes, isTargeted: $targeted) { providers in
            guard enabled else { return false }
            return Self.takeDrop(providers, into: onDropURL)
        }
    }

    private static let dropTypes: [UTType] = {
        var types: [UTType] = [.fileURL, .commaSeparatedText, .spreadsheet, .data]
        if let xlsx = UTType(filenameExtension: "xlsx") { types.insert(xlsx, at: 0) }
        if let csv = UTType(filenameExtension: "csv") { types.append(csv) }
        return types
    }()

    private static func takeDrop(_ providers: [NSItemProvider], into onDropURL: @escaping (URL) -> Void) -> Bool {
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let value = item as? URL {
                    url = value
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let text = item as? String {
                    url = URL(string: text)
                } else {
                    url = nil
                }
                guard let url else { return }
                DispatchQueue.main.async { onDropURL(url) }
            }
            return true
        }

        let fallbacks = [
            "org.openxmlformats.spreadsheetml.sheet",
            UTType.commaSeparatedText.identifier,
            UTType.data.identifier,
        ]
        for typeId in fallbacks {
            guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(typeId) }) else { continue }
            provider.loadDataRepresentation(forTypeIdentifier: typeId) { data, _ in
                guard let data else { return }
                let ext = typeId.contains("comma") ? "csv" : "xlsx"
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent("heartbeat-drop-\(UUID().uuidString).\(ext)")
                try? data.write(to: dest)
                DispatchQueue.main.async { onDropURL(dest) }
            }
            return true
        }
        return false
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
