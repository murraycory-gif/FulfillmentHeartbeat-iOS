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

    func rows(for section: MetricSection, relaxUnknown: Bool = false) -> [MetricRow] {
        let sectionRows = rows.filter { $0.section == section }
        return HeartbeatMath.filtered(
            sectionRows,
            division: filters.division,
            district: filters.district,
            om: filters.om,
            store: filters.store,
            relaxUnknown: relaxUnknown
        )
    }

    func latest(for section: MetricSection, relaxUnknown: Bool = false) -> [MetricRow] {
        if section == .pickerScorecard {
            return HeartbeatMath.latestPerShopper(rows(for: section, relaxUnknown: relaxUnknown))
        }
        return HeartbeatMath.latestPerStore(rows(for: section, relaxUnknown: relaxUnknown))
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

    var divisions: [String] { distinct(rows.map(\.division)) }

    var districts: [String] { districts(in: nil) }

    var operationsOMs: [String] { operationsOMs(in: nil) }

    var stores: [(number: String, name: String?)] { stores(in: nil) }

    func divisions(in scope: MetricSection?) -> [String] {
        distinct(source(scope).map(\.division))
    }

    func districts(in scope: MetricSection?) -> [String] {
        let sourceRows = source(scope)
        let division = HeartbeatMath.usableFilter(filters.division, in: sourceRows.map(\.division), relax: scope != nil)
        return sourceRows
            .filter { division == nil || HeartbeatMath.matches($0.division, division ?? "") }
            .map(\.district)
            .filter { !$0.isEmpty }
            .uniqued()
            .sorted()
    }

    func operationsOMs(in scope: MetricSection?) -> [String] {
        let sourceRows = source(scope)
        let division = HeartbeatMath.usableFilter(filters.division, in: sourceRows.map(\.division), relax: scope != nil)
        let district = HeartbeatMath.usableFilter(filters.district, in: sourceRows.map(\.district), relax: scope != nil)
        return sourceRows
            .filter { division == nil || HeartbeatMath.matches($0.division, division ?? "") }
            .filter { district == nil || HeartbeatMath.matches($0.district, district ?? "") }
            .map(\.operationsOM)
            .filter { value in
                !value.isEmpty && value.rangeOfCharacter(from: .letters) != nil
            }
            .uniqued()
            .sorted()
    }

    func stores(in scope: MetricSection?) -> [(number: String, name: String?)] {
        let sourceRows = source(scope)
        let division = HeartbeatMath.usableFilter(filters.division, in: sourceRows.map(\.division), relax: scope != nil)
        let district = HeartbeatMath.usableFilter(filters.district, in: sourceRows.map(\.district), relax: scope != nil)
        let om = HeartbeatMath.usableFilter(filters.om, in: sourceRows.map(\.operationsOM), relax: scope != nil)
        var seen: [String: String?] = [:]
        for row in sourceRows {
            if let division, !HeartbeatMath.matches(row.division, division) { continue }
            if let district, !HeartbeatMath.matches(row.district, district) { continue }
            if let om, !HeartbeatMath.matches(row.operationsOM, om) { continue }
            if row.storeNumber.isEmpty { continue }
            if seen[row.storeNumber] == nil {
                seen[row.storeNumber] = row.storeName
            }
        }
        return seen.keys.sorted(by: HeartbeatFormat.storeOrder).map { ($0, seen[$0] ?? nil) }
    }

    func ignoredFilters(for section: MetricSection) -> [String] {
        let sectionRows = rows.filter { $0.section == section }
        var ignored: [String] = []
        if HeartbeatMath.usableFilter(filters.division, in: sectionRows.map(\.division), relax: true) == nil,
           !filters.division.isEmpty {
            ignored.append(filters.division)
        }
        if HeartbeatMath.usableFilter(filters.district, in: sectionRows.map(\.district), relax: true) == nil,
           !filters.district.isEmpty {
            ignored.append("District \(filters.district)")
        }
        if HeartbeatMath.usableFilter(filters.om, in: sectionRows.map(\.operationsOM), relax: true) == nil,
           !filters.om.isEmpty {
            ignored.append(filters.om)
        }
        if HeartbeatMath.usableFilter(filters.store, in: sectionRows.map(\.storeNumber), relax: true) == nil,
           !filters.store.isEmpty {
            ignored.append("Store \(filters.store)")
        }
        return ignored
    }

    private func source(_ scope: MetricSection?) -> [MetricRow] {
        guard let scope else { return rows }
        return rows.filter { $0.section == scope }
    }

    private func distinct(_ values: [String]) -> [String] {
        values.filter { !$0.isEmpty }.uniqued().sorted()
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
