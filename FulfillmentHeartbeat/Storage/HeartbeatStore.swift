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
    private let checklistURL: URL
    private var hydrating = false
    private var checklistByKey: [String: ChecklistItem] = [:]
    private var commentSaveTask: Task<Void, Never>?
    private var latestBySection: [MetricSection: [MetricRow]] = [:]
    private var roster: [String: HeartbeatMath.StoreIdentity] = [:]
    private var filteredLatest: [MetricSection: [MetricRow]] = [:]
    private var filteredMarket: [HeartbeatMath.MarketStore] = []
    private var cachedDivisions: [String] = []
    private var cachedDistricts: [String] = []
    private var cachedOMs: [String] = []
    private var cachedStores: [(number: String, name: String?)] = []
    private var cachedSummaries: [SectionSummary] = []
    private var cachedPickerBoard = HeartbeatMath.PickerBoard(
        shopperCount: 0,
        opportunityCount: 0,
        strongCount: 0,
        opportunity: [],
        strong: []
    )
    private var cachedChecklistGroups: [MetricSection: [ChecklistDriverGroup]] = [:]

    init(rootURL: URL? = nil) {
        fileManager = .default
        let root = rootURL ?? Self.defaultRoot()
        if !fileManager.fileExists(atPath: root.path) {
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        snapshotURL = root.appendingPathComponent("heartbeat.json")
        checklistURL = root.appendingPathComponent("checklist.json")
        rows = []
        uploads = []
        seeded = false
        filters = DashboardFilters()
        loadChecklist()
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
        if section == .pickerScorecard { return latest }
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

    var pickerBoard: HeartbeatMath.PickerBoard { cachedPickerBoard }

    func checklistItem(for section: MetricSection) -> ChecklistItem {
        checklistByKey[checklistKey(for: section)]
            ?? ChecklistItem(sectionRaw: section.rawValue)
    }

    func setChecklistStatus(_ status: ChecklistStatus, for section: MetricSection) {
        var item = checklistItem(for: section)
        item.status = item.status == status ? .open : status
        item.updatedAt = Date()
        checklistByKey[checklistKey(for: section)] = item
        persistChecklist()
        objectWillChange.send()
    }

    func setChecklistComment(_ comment: String, for section: MetricSection) {
        var item = checklistItem(for: section)
        item.comment = comment
        item.updatedAt = Date()
        checklistByKey[checklistKey(for: section)] = item
        objectWillChange.send()
        commentSaveTask?.cancel()
        commentSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await self?.persistChecklist()
        }
    }

    var checklistOpenCount: Int {
        MetricSection.checklistSections.filter { !checklistItem(for: $0).status.isClosed }.count
    }

    var checklistReadyToSend: Bool {
        MetricSection.checklistSections.allSatisfy { checklistItem(for: $0).status.isClosed }
    }

    func checklistDrivers(for section: MetricSection, limit: Int = 10) -> [String] {
        checklistGroups(for: section).flatMap(\.lines).prefix(limit).map { $0 }
    }

    func checklistGroups(for section: MetricSection) -> [ChecklistDriverGroup] {
        cachedChecklistGroups[section] ?? []
    }

    func checklistEmailText() -> String {
        var lines: [String] = [
            "eCommerce Fulfillment Checklist",
            filters.summary,
            HeartbeatFormat.relative(Date()),
            "",
        ]
        for section in MetricSection.checklistSections {
            let summary = self.summary(for: section)
            let item = checklistItem(for: section)
            lines.append("\(section.title) — \(summary.health.label) — \(summary.headlineText)")
            lines.append("Status: \(item.status.label)")
            let drivers = checklistGroups(for: section)
            for group in drivers {
                lines.append("\(group.title):")
                for line in group.lines {
                    lines.append("  • \(line)")
                }
            }
            if !item.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("Comments: \(item.comment)")
            }
            lines.append("")
        }
        lines.append("Sent from Fulfillment Heartbeat")
        return lines.joined(separator: "\n")
    }

    func checklistEmailSubject() -> String {
        "Fulfillment Checklist — \(filters.summary)"
    }

    private func checklistKey(for section: MetricSection) -> String {
        "\(filters.division)|\(filters.district)|\(filters.om)|\(filters.store)|\(section.rawValue)"
    }

    private func healthRank(_ health: Health) -> Int {
        switch health {
        case .risk: return 3
        case .watch: return 2
        case .good: return 1
        case .none: return 0
        }
    }

    private func buildChecklistGroups(_ latest: [MetricSection: [MetricRow]]) -> [MetricSection: [ChecklistDriverGroup]] {
        var groups: [MetricSection: [ChecklistDriverGroup]] = [:]
        for section in MetricSection.dashboardCards {
            let rows = HeartbeatMath.topOpportunityStores(section: section, rows: latest[section] ?? [], limit: 10)
            let lines = rows.map { row in
                let cell = StoreCellViewModel.make(section: section, row: row)
                let health = HeartbeatMath.health(for: section, row: row)
                let division = row.division.isEmpty ? identity(forStore: row.storeNumber).division : row.division
                return "Store \(row.storeNumber)\(division.isEmpty ? "" : " · \(division)") · \(cell.primary) · \(health.label)"
            }
            if !lines.isEmpty {
                groups[section] = [ChecklistDriverGroup(title: "Top \(lines.count) opportunity stores", lines: lines)]
            }
        }
        let pickerGroups = HeartbeatMath.topPickersByMetric(latest[.pickerScorecard] ?? [], limit: 10).map { board in
            ChecklistDriverGroup(
                title: "Top \(board.rows.count) \(board.metric)",
                lines: board.rows.map { row in
                    let division = row.division.isEmpty ? identity(forStore: row.storeNumber).division : row.division
                    let value: String
                    switch board.metric {
                    case "PPH": value = HeartbeatFormat.num(row.number("pph"), digits: 1)
                    case "Presub": value = HeartbeatFormat.pct(row.number("presub_pct"))
                    case "OTH": value = HeartbeatFormat.pct(row.number("oth5_pct"))
                    case "COE": value = HeartbeatFormat.pct(row.number("coe_pct"))
                    default: value = HeartbeatFormat.pct(row.number("ott_pct"))
                    }
                    return "\(row.shopperName) · \(row.storeNumber)\(division.isEmpty ? "" : " · \(division)") · \(value)"
                }
            )
        }
        if !pickerGroups.isEmpty {
            groups[.pickerScorecard] = pickerGroups
        }
        return groups
    }

    func identity(forStore number: String) -> HeartbeatMath.StoreIdentity {
        roster[HeartbeatMath.canonicalStore(number)]
            ?? HeartbeatMath.StoreIdentity(division: "", district: "", om: "", name: nil)
    }

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
        MetricSection.allCases
            .filter { $0 != .pickerScorecard }
            .flatMap { latestBySection[$0] ?? [] }
    }

    private func replaceFilters(_ next: DashboardFilters) {
        if filters == next {
            applyFilters()
            return
        }
        filters = next
    }

    private func rebuildIndex() {
        let identitySource = rows.filter {
            $0.section != .scheduleQuality && $0.section != .dynacap && $0.section != .pickerScorecard
        }
        roster = HeartbeatMath.storeRoster(identitySource.isEmpty ? rows.filter { $0.section != .pickerScorecard } : identitySource)
        var latest: [MetricSection: [MetricRow]] = [:]
        for section in MetricSection.allCases {
            let sectionRows = rows.filter { $0.section == section }
            if section == .dynacap {
                latest[section] = HeartbeatMath.materializeDistrictMetric(sectionRows, roster: roster)
            } else if section == .scheduleQuality || section == .fiveStar || section == .prepNotReady {
                latest[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(sectionRows), roster: roster)
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
        for section in MetricSection.allCases where section != .pickerScorecard {
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
        let pickers = latestBySection[.pickerScorecard] ?? []
        if let allowed = pickerStoreSet() {
            nextLatest[.pickerScorecard] = pickers.filter { allowed.contains(HeartbeatMath.canonicalStore($0.storeNumber)) }
        } else {
            nextLatest[.pickerScorecard] = pickers
        }
        filteredLatest = nextLatest
        cachedPickerBoard = HeartbeatMath.pickerBoard(nextLatest[.pickerScorecard] ?? [])
        cachedChecklistGroups = buildChecklistGroups(nextLatest)
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

    private func pickerStoreSet() -> Set<String>? {
        if filters.division.isEmpty, filters.district.isEmpty, filters.om.isEmpty, filters.store.isEmpty {
            return nil
        }
        var allowed: Set<String> = []
        for (number, identity) in roster {
            if !filters.division.isEmpty, !HeartbeatMath.matches(identity.division, filters.division) { continue }
            if !filters.district.isEmpty, !HeartbeatMath.matches(identity.district, filters.district) { continue }
            if !filters.om.isEmpty, !HeartbeatMath.matches(identity.om, filters.om) { continue }
            if !filters.store.isEmpty, !HeartbeatMath.matches(number, filters.store) { continue }
            allowed.insert(number)
        }
        return allowed
    }

    private func load() {
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
            rebuildIndex()
            applyFilters()
            return
        }
        let url = snapshotURL
        Task.detached(priority: .userInitiated) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decoded = try decoder.decode(HeartbeatSnapshot.self, from: data)
                await MainActor.run {
                    self.hydrate(decoded)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Could not load saved pulse: \(error.localizedDescription)"
                }
            }
        }
    }

    private func hydrate(_ decoded: HeartbeatSnapshot) {
        hydrating = true
        rows = decoded.rows
        uploads = decoded.uploads.sorted { $0.uploadedAt > $1.uploadedAt }
        seeded = decoded.seeded
        filters = decoded.filters
        hydrating = false
        rebuildIndex()
        applyFilters()
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

    private func loadChecklist() {
        guard fileManager.fileExists(atPath: checklistURL.path),
              let data = try? Data(contentsOf: checklistURL)
        else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([String: ChecklistItem].self, from: data) else { return }
        checklistByKey = decoded
    }

    private func persistChecklist() {
        let items = checklistByKey
        let url = checklistURL
        Task.detached(priority: .utility) {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(items)
                try data.write(to: url, options: [.atomic])
            } catch {}
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
