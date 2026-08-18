import Foundation

@MainActor
final class HeartbeatStore: ObservableObject {
    @Published private(set) var rows: [MetricRow]
    @Published private(set) var uploads: [UploadRecord]
    @Published private(set) var seeded: Bool
    @Published var filters: DashboardFilters {
        didSet {
            guard !hydrating, oldValue != filters else { return }
            applyFilters()
        }
    }
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var lastImportedSection: MetricSection? = nil
    @Published var isImporting = false
    @Published var importLabel: String?

    private let fileManager: FileManager
    private let snapshotURL: URL
    private var hydrating = false
    private var latestBySection: [MetricSection: [MetricRow]] = [:]
    private var roster: [String: HeartbeatMath.StoreIdentity] = [:]
    private var filteredLatest: [MetricSection: [MetricRow]] = [:]
    private var filteredMarket: [HeartbeatMath.MarketStore] = []
    private var cachedDivisions: [String] = []
    private var cachedDistricts: [String] = []
    private var cachedOMs: [String] = []
    private var cachedStores: [(number: String, name: String?)] = []
    private var cachedSummaries: [SectionSummary] = []

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

    func rows(for section: MetricSection, relaxUnknown: Bool = false) -> [MetricRow] {
        if relaxUnknown {
            return HeartbeatMath.filtered(
                latestBySection[section] ?? [],
                division: filters.division,
                district: filters.district,
                om: filters.om,
                store: filters.store,
                relaxUnknown: true,
                universe: latestUniverse
            )
        }
        return filteredLatest[section] ?? []
    }

    func marketStores() -> [HeartbeatMath.MarketStore] { filteredMarket }

    func latest(for section: MetricSection, relaxUnknown: Bool = false) -> [MetricRow] {
        rows(for: section, relaxUnknown: relaxUnknown)
    }

    func displayRows(for section: MetricSection) -> [MetricRow] {
        let latest = filteredLatest[section] ?? []
        if !latest.isEmpty { return latest }
        return filteredMarket.map { store in
            MetricRow(
                section: section,
                division: store.division,
                operationsOM: store.om,
                storeNumber: store.storeNumber,
                payload: [:],
                textPayload: ["district": store.district, "placeholder": "1"]
            )
        }
    }

    func summary(for section: MetricSection) -> SectionSummary {
        cachedSummaries.first { $0.section == section }
            ?? HeartbeatMath.summarize(section, rows: [], upload: upload(for: section))
    }

    func upload(for section: MetricSection) -> UploadRecord? {
        uploads.first { $0.section == section }
    }

    var summaries: [SectionSummary] { cachedSummaries }

    var lastUpload: UploadRecord? {
        uploads.max(by: { $0.uploadedAt < $1.uploadedAt })
    }

    var divisions: [String] { cachedDivisions }
    var districts: [String] { cachedDistricts }
    var operationsOMs: [String] { cachedOMs }
    var stores: [(number: String, name: String?)] { cachedStores }

    func history(for section: MetricSection) -> [HistoryPoint] {
        let sectionRows = rows.filter { $0.section == section }
        return HeartbeatMath.history(
            section,
            rows: HeartbeatMath.filtered(
                sectionRows,
                division: filters.division,
                district: filters.district,
                om: filters.om,
                store: filters.store,
                relaxUnknown: false,
                universe: sectionRows + latestUniverse
            )
        )
    }

    func setDivision(_ value: String) {
        replaceFilters(DashboardFilters(division: value, district: "", om: "", store: ""))
    }

    func setDistrict(_ value: String) {
        var next = filters
        next.district = value
        next.om = ""
        next.store = ""
        replaceFilters(next)
    }

    func setOM(_ value: String) {
        var next = filters
        next.om = value
        next.store = ""
        replaceFilters(next)
    }

    func setStore(_ value: String) {
        var next = filters
        next.store = value
        replaceFilters(next)
    }

    func clearFilters() {
        replaceFilters(DashboardFilters())
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
        rebuildIndex()
        replaceFilters(DashboardFilters())
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
        rebuildIndex()
        replaceFilters(DashboardFilters())
        let stores = Set(incoming.map(\.storeNumber).filter { !$0.isEmpty }).count
        statusMessage = "Imported \(incoming.count) rows · \(stores) stores into \(section.title). Filters cleared so the new file is in view."
        persist()
    }

    func clearSection(_ section: MetricSection) {
        rows.removeAll { $0.section == section }
        uploads.removeAll { $0.section == section }
        if rows.isEmpty { seeded = false }
        rebuildIndex()
        applyFilters()
        persist()
    }

    func clearAll() {
        rows = []
        uploads = []
        seeded = false
        rebuildIndex()
        applyFilters()
        persist()
    }

    private var latestUniverse: [MetricRow] {
        MetricSection.allCases.flatMap { latestBySection[$0] ?? [] }
    }

    private func replaceFilters(_ next: DashboardFilters) {
        if filters == next {
            applyFilters()
            return
        }
        filters = next
    }

    private func rebuildIndex() {
        roster = HeartbeatMath.storeRoster(rows)
        var latest: [MetricSection: [MetricRow]] = [:]
        for section in MetricSection.allCases {
            let sectionRows = rows.filter { $0.section == section }
            if section == .dynacap {
                latest[section] = HeartbeatMath.materializeDistrictMetric(sectionRows, roster: roster)
            } else if section == .pickerScorecard {
                latest[section] = HeartbeatMath.latestPerShopper(sectionRows)
            } else {
                latest[section] = HeartbeatMath.latestPerStore(sectionRows)
            }
        }
        latestBySection = latest
        cachedDivisions = roster.values.map(\.division).filter { !$0.isEmpty }.uniqued().sorted()
    }

    private func applyFilters() {
        let universe = latestUniverse
        var nextLatest: [MetricSection: [MetricRow]] = [:]
        for section in MetricSection.allCases {
            nextLatest[section] = HeartbeatMath.filtered(
                latestBySection[section] ?? [],
                division: filters.division,
                district: filters.district,
                om: filters.om,
                store: filters.store,
                relaxUnknown: false,
                universe: universe
            )
        }
        filteredLatest = nextLatest
        filteredMarket = HeartbeatMath.marketBoard(
            universe,
            division: filters.division,
            district: filters.district,
            om: filters.om,
            store: filters.store
        )
        refreshFilterOptions()
        cachedSummaries = MetricSection.dashboardCards.map { section in
            var summary = HeartbeatMath.summarize(section, rows: nextLatest[section] ?? [], upload: upload(for: section))
            if summary.storeCount == 0, !filteredMarket.isEmpty {
                summary.secondary = "No \(section.short) data for \(filteredMarket.count) stores in this filter"
                summary.health = .none
            }
            return summary
        }
        objectWillChange.send()
    }

    private func refreshFilterOptions() {
        cachedDistricts = roster.values
            .filter { filters.division.isEmpty || HeartbeatMath.matches($0.division, filters.division) }
            .map(\.district)
            .filter { !$0.isEmpty }
            .uniqued()
            .sorted()
        cachedOMs = roster.values
            .filter { filters.division.isEmpty || HeartbeatMath.matches($0.division, filters.division) }
            .filter { filters.district.isEmpty || HeartbeatMath.matches($0.district, filters.district) }
            .map(\.om)
            .filter { value in
                !value.isEmpty && value.rangeOfCharacter(from: .letters) != nil
            }
            .uniqued()
            .sorted()
        var seen: [String: String?] = [:]
        for (number, identity) in roster {
            if !filters.division.isEmpty, !HeartbeatMath.matches(identity.division, filters.division) { continue }
            if !filters.district.isEmpty, !HeartbeatMath.matches(identity.district, filters.district) { continue }
            if !filters.om.isEmpty, !HeartbeatMath.matches(identity.om, filters.om) { continue }
            if seen[number] == nil { seen[number] = identity.name }
        }
        cachedStores = seen.keys.sorted(by: HeartbeatFormat.storeOrder).map { ($0, seen[$0] ?? nil) }
    }

    private func load() {
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
            rebuildIndex()
            applyFilters()
            return
        }
        do {
            let data = try Data(contentsOf: snapshotURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(HeartbeatSnapshot.self, from: data)
            hydrating = true
            rows = decoded.rows
            uploads = decoded.uploads.sorted { $0.uploadedAt > $1.uploadedAt }
            seeded = decoded.seeded
            filters = decoded.filters
            hydrating = false
            rebuildIndex()
            applyFilters()
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
