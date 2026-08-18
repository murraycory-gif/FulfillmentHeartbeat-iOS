import Foundation

@MainActor
final class HeartbeatStore: ObservableObject {
    @Published private(set) var rows: [MetricRow]
    @Published private(set) var uploads: [UploadRecord]
    @Published private(set) var seeded: Bool
    @Published var filters: DashboardFilters {
        didSet { persist() }
    }
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var lastImportedSection: MetricSection? = nil
    @Published var isImporting = false
    @Published var importLabel: String?

    private let fileManager: FileManager
    private let snapshotURL: URL

    init(rootURL: URL? = nil) {
        fileManager = .default
        let root = rootURL ?? Self.defaultRoot()
        if !fileManager.fileExists(atPath: root.path) {
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        snapshotURL = root.appendingPathComponent("heartbeat.json")
        rows = []
        uploads = []
        seeded = false
        filters = DashboardFilters()
        load()
    }

    private static func defaultRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("FulfillmentHeartbeat", isDirectory: true)
    }

    var filteredRows: [MetricRow] {
        HeartbeatMath.filtered(
            rows,
            division: filters.division,
            district: filters.district,
            om: filters.om,
            store: filters.store
        )
    }

    func rows(for section: MetricSection) -> [MetricRow] {
        filteredRows.filter { $0.section == section }
    }

    func latest(for section: MetricSection) -> [MetricRow] {
        if section == .pickerScorecard {
            return HeartbeatMath.latestPerShopper(rows(for: section))
        }
        return HeartbeatMath.latestPerStore(rows(for: section))
    }

    func upload(for section: MetricSection) -> UploadRecord? {
        uploads.first { $0.section == section }
    }

    func summary(for section: MetricSection) -> SectionSummary {
        HeartbeatMath.summarize(section, rows: rows(for: section), upload: upload(for: section))
    }

    var summaries: [SectionSummary] {
        MetricSection.dashboardCards.map { summary(for: $0) }
    }

    var lastUpload: UploadRecord? {
        uploads.max(by: { $0.uploadedAt < $1.uploadedAt })
    }

    var divisions: [String] {
        Array(Set(rows.map(\.division).filter { !$0.isEmpty })).sorted()
    }

    var districts: [String] {
        rows
            .filter { filters.division.isEmpty || $0.division == filters.division }
            .map(\.district)
            .filter { !$0.isEmpty }
            .uniqued()
            .sorted()
    }

    var operationsOMs: [String] {
        rows
            .filter { filters.division.isEmpty || $0.division == filters.division }
            .filter { filters.district.isEmpty || $0.district == filters.district }
            .map(\.operationsOM)
            .filter { value in
                !value.isEmpty && value.rangeOfCharacter(from: .letters) != nil
            }
            .uniqued()
            .sorted()
    }

    var stores: [(number: String, name: String?)] {
        var seen: [String: String?] = [:]
        for row in rows {
            if !filters.division.isEmpty, row.division != filters.division { continue }
            if !filters.district.isEmpty, row.district != filters.district { continue }
            if !filters.om.isEmpty, row.operationsOM != filters.om { continue }
            if row.storeNumber.isEmpty { continue }
            if seen[row.storeNumber] == nil {
                seen[row.storeNumber] = row.storeName
            }
        }
        return seen.keys.sorted(by: HeartbeatFormat.storeOrder).map { ($0, seen[$0] ?? nil) }
    }

    func setDivision(_ value: String) {
        filters.division = value
        filters.district = ""
        filters.om = ""
        filters.store = ""
    }

    func setDistrict(_ value: String) {
        filters.district = value
        filters.om = ""
        filters.store = ""
    }

    func setOM(_ value: String) {
        filters.om = value
        filters.store = ""
    }

    func setStore(_ value: String) {
        filters.store = value
    }

    func clearFilters() {
        filters = DashboardFilters()
    }

    func loadSampleMarket() {
        let sample = SampleMarket.rows()
        rows = sample
        uploads = MetricSection.allCases.map { section in
            UploadRecord(
                section: section,
                filename: "sample-\(section.rawValue).csv",
                rowCount: sample.filter { $0.section == section }.count
            )
        }
        seeded = true
        lastImportedSection = nil
        clearFilters()
        statusMessage = "Sample market loaded — 16 Chicago-area stores."
        persist()
    }

    func importWorkbook(url: URL, section: MetricSection) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            Task { await runImport(data: data, filename: url.lastPathComponent, section: section) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importWorkbook(data: Data, filename: String, section: MetricSection) {
        Task { await runImport(data: data, filename: filename, section: section) }
    }

    private func runImport(data: Data, filename: String, section: MetricSection) async {
        guard !isImporting else { return }
        isImporting = true
        importLabel = "Reading \(filename)…"
        errorMessage = nil
        do {
            let incoming = try await Task.detached(priority: .userInitiated) {
                let parsed = try WorkbookParser.parse(data: data, filename: filename)
                if parsed.isEmpty { throw WorkbookParser.ParseError.empty }
                return parsed.map { $0.asRow(section: section) }
            }.value
            applyImport(incoming, filename: filename, section: section)
        } catch {
            errorMessage = error.localizedDescription
        }
        isImporting = false
        importLabel = nil
    }

    private func applyImport(_ incoming: [MetricRow], filename: String, section: MetricSection) {
        rows.removeAll { $0.section == section }
        rows.append(contentsOf: incoming)
        uploads.removeAll { $0.section == section }
        uploads.insert(UploadRecord(section: section, filename: filename, rowCount: incoming.count), at: 0)
        seeded = true
        lastImportedSection = section
        clearFilters()
        let stores = Set(incoming.map(\.storeNumber).filter { !$0.isEmpty }).count
        statusMessage = "Imported \(incoming.count) rows · \(stores) stores into \(section.title). Filters cleared so the new file is in view."
        persist()
    }

    func clearSection(_ section: MetricSection) {
        rows.removeAll { $0.section == section }
        uploads.removeAll { $0.section == section }
        if rows.isEmpty { seeded = false }
        persist()
    }

    func clearAll() {
        rows = []
        uploads = []
        seeded = false
        persist()
    }

    private func load() {
        guard fileManager.fileExists(atPath: snapshotURL.path) else { return }
        do {
            let data = try Data(contentsOf: snapshotURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(HeartbeatSnapshot.self, from: data)
            rows = decoded.rows
            uploads = decoded.uploads.sorted { $0.uploadedAt > $1.uploadedAt }
            seeded = decoded.seeded
            filters = decoded.filters
        } catch {
            errorMessage = "Could not load saved pulse: \(error.localizedDescription)"
        }
    }

    private func persist() {
        let snapshot = HeartbeatSnapshot(
            rows: rows,
            uploads: uploads,
            seeded: seeded,
            filters: filters
        )
        let url = snapshotURL
        Task.detached(priority: .utility) {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: [.atomic])
            } catch {
                // Keep the in-memory pulse; the next successful save will replace this file.
            }
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
