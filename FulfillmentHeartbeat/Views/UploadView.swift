import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct UploadView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @State private var importTarget: MetricSection?
    @State private var exportItem: ExportItem?
    @State private var showStatus = false
    @State private var showError = false
    @State private var inboxFiles: [URL] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upload workbooks")
                        .font(.largeTitle.weight(.semibold))
                    Text("Copy each Excel into Files → On My iPad → Heartbeat, then tap Pick file on the matching card. Do not drag files — that crashes on this iPad.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                inboxCard

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

                Text("Headers can be flexible — Division, Operations OM, and Store Number are picked up automatically. Use Link to pull the raw Power BI export, or Template for a clean file.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .sheet(item: $importTarget) { section in
            FilePickSheet(
                section: section,
                files: inboxFiles,
                onImport: { url in
                    store.importWorkbook(url: url, section: section)
                    importTarget = nil
                },
                onRefresh: { inboxFiles = store.inboxWorkbooks() }
            )
        }
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
        .onAppear { inboxFiles = store.inboxWorkbooks() }
        .onChange(of: store.statusMessage) { _, message in
            showStatus = message != nil
            inboxFiles = store.inboxWorkbooks()
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

    private var inboxCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Heartbeat folder")
                .font(.title3.weight(.bold))
            Text("Put the Excel in Files → On My iPad → Heartbeat, then tap Import next to it. Do not drag files onto the cards.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            if inboxFiles.isEmpty {
                Text("No .xlsx or .csv files in the Heartbeat folder yet.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(inboxFiles, id: \.path) { url in
                    HStack(spacing: 12) {
                        Image(systemName: "doc")
                            .foregroundStyle(AppTheme.blue)
                        Text(url.lastPathComponent)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Spacer()
                        Menu("Import") {
                            ForEach(MetricSection.uploadOrder) { section in
                                Button(section.title) {
                                    store.importWorkbook(url: url, section: section)
                                }
                            }
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.blue, in: Capsule())
                    }
                    .padding(12)
                    .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            Button("Refresh folder") {
                inboxFiles = store.inboxWorkbooks()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.blue)
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func beginImport(_ section: MetricSection) {
        inboxFiles = store.inboxWorkbooks()
        importTarget = section
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
                Image(systemName: "folder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.blue)
                Text("Pick a file from Heartbeat")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text("Files → On My iPad → Heartbeat")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                Text("Pick file")
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
    }
}

struct FilePickSheet: View {
    let section: MetricSection
    let files: [URL]
    let onImport: (URL) -> Void
    let onRefresh: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import \(section.title)")
                        .font(.title2.weight(.bold))
                    Text("Tap a file already in Heartbeat. If the list is empty, copy the Excel into Files → On My iPad → Heartbeat first.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .font(.subheadline.weight(.semibold))
            }

            if files.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No Excel files in Heartbeat yet")
                        .font(.headline)
                    Text("1. Keep the iPad plugged into the Mac")
                    Text("2. Finder → iPad in the sidebar → Files → Heartbeat")
                    Text("3. Drop the Excel into that Heartbeat folder")
                    Text("4. Come back here and tap Refresh, then Use")
                }
                .font(.subheadline)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(files, id: \.path) { url in
                            Button {
                                onImport(url)
                            } label: {
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundStyle(AppTheme.blue)
                                    Text(url.lastPathComponent)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Text("Use")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.blue, in: Capsule())
                                }
                                .padding(14)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Button("Refresh list", action: onRefresh)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 480)
        .background(AppTheme.bg)
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
