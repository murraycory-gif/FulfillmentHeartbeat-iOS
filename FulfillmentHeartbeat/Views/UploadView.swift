import SwiftUI
import UniformTypeIdentifiers

struct UploadView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @State private var importing: MetricSection?
    @State private var exportItem: ExportItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upload workbooks")
                            .font(.largeTitle.weight(.semibold))
                        Text("One Excel or CSV file per section. A new file replaces that section.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Button {
                        store.loadSampleMarket()
                    } label: {
                        Label("Load sample market", systemImage: "sparkles")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                    ForEach(MetricSection.allCases) { section in
                        UploadPanel(
                            section: section,
                            upload: store.upload(for: section),
                            onImport: { importing = section },
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

                Text("Headers can be flexible — Division, Operations OM, and Store Number are picked up automatically. Download a template if you want a clean start.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .fileImporter(
            isPresented: Binding(
                get: { importing != nil },
                set: { if !$0 { importing = nil } }
            ),
            allowedContentTypes: Self.workbookTypes,
            allowsMultipleSelection: false
        ) { result in
            guard let section = importing else { return }
            importing = nil
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    store.importWorkbook(url: url, section: section)
                }
            case .failure(let error):
                store.errorMessage = error.localizedDescription
            }
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
        .alert("Couldn’t import", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private static var workbookTypes: [UTType] {
        var types: [UTType] = [.commaSeparatedText, .plainText, .spreadsheet]
        if let xlsx = UTType(filenameExtension: "xlsx") {
            types.insert(xlsx, at: 0)
        }
        if let csv = UTType(filenameExtension: "csv") {
            types.append(csv)
        }
        return types
    }
}

struct UploadPanel: View {
    let section: MetricSection
    let upload: UploadRecord?
    let onImport: () -> Void
    let onTemplate: () -> Void
    let onClear: () -> Void

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: section.symbol)
                        .font(.title3)
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(.headline)
                        Text(section.blurb)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                if let upload {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(upload.filename)
                            .font(.subheadline.weight(.medium))
                        Text("\(upload.rowCount) rows · \(HeartbeatFormat.relative(upload.uploadedAt))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
                } else {
                    Text("No file yet")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textTertiary)
                }

                HStack(spacing: 8) {
                    Button("Choose file", action: onImport)
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Template", action: onTemplate)
                        .buttonStyle(SecondaryButtonStyle())
                    if upload != nil {
                        Button("Clear", action: onClear)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.bad)
                    }
                }
            }
        }
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
}
