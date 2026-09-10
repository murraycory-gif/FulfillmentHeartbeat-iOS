import Foundation

/// Seat-scoped pack contract. Cook and the iPad share this plane.
/// Market `current.sqlite` is never the hub primary while a seat is active.
enum PulseSeatPack {
    static let schemaVersion = 1
    static let manifestObject = "packs/manifest.json"
    /// District / store sqlites are small. Do not use the 50 KB market floor.
    static let minimumSeatBytes = 2_000

    static func isUsable(at url: URL) -> Bool {
        PulseSQLite.exists(at: url) && PulseSQLite.fileBytes(at: url) >= minimumSeatBytes
    }

    enum Grain: String, Codable, CaseIterable {
        case company
        case district
        case store
    }

    struct Key: Hashable, Codable, Equatable {
        var grain: Grain
        var id: String

        static let company = Key(grain: .company, id: "all")

        var slug: String {
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            let safe = trimmed
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "\\", with: "-")
                .replacingOccurrences(of: " ", with: "-")
            return safe.isEmpty ? "unknown" : safe
        }

        var objectPath: String {
            "packs/seat/\(grain.rawValue)/\(slug)/current.sqlite"
        }

        var filters: DashboardFilters {
            var next = DashboardFilters()
            switch grain {
            case .company:
                break
            case .district:
                next.district = id
            case .store:
                next.store = id
            }
            return next
        }

        var dashboardGrain: DashScopeGrain {
            switch grain {
            case .company: return .region
            case .district, .store: return .store
            }
        }

        static func forSeat(filters: DashboardFilters, role _: HeartbeatRole?) -> Key {
            if let store = filters.stores.first, !store.isEmpty {
                return Key(grain: .store, id: HeartbeatMath.canonicalStore(store))
            }
            if let district = filters.districts.first, !district.isEmpty {
                return Key(grain: .district, id: HeartbeatMath.canonicalDistrict(district))
            }
            return .company
        }
    }

    struct Entry: Codable, Equatable {
        var grain: String
        var id: String
        var path: String
        var storeCount: Int
        var bytes: Int
        var sectionStoreCounts: [String: Int]
    }

    struct Manifest: Codable, Equatable {
        var schema: Int
        var stamp: String
        var cookedAt: String
        var company: Entry
        var districts: [Entry]
        var stores: [Entry]

        var allEntries: [Entry] { [company] + districts + stores }

        func entry(for key: Key) -> Entry? {
            allEntries.first { $0.grain == key.grain.rawValue && $0.id == key.slug }
        }
    }

    /// Market `current.sqlite` may feed Who's looking / Clear. Never the hub under a seat.
    static func shouldUseMarketPackAsPrimary(seatActive: Bool) -> Bool { !seatActive }

    /// `.380` data plane. Banned — seat sqlite is the warehouse.
    static func shouldApplySeatSliceOfMarketWarehouse() -> Bool { false }

    static func shouldMergeSeatWithCompanyOnSwap() -> Bool { false }

    static func shouldPaintHubFromActiveSeatSQLite() -> Bool { true }

    static func localURL(root: URL, key: Key) -> URL {
        root
            .appendingPathComponent("packs", isDirectory: true)
            .appendingPathComponent("seat", isDirectory: true)
            .appendingPathComponent(key.grain.rawValue, isDirectory: true)
            .appendingPathComponent(key.slug, isDirectory: true)
            .appendingPathComponent("current.sqlite")
    }

    static func shopperSections() -> Set<MetricSection> {
        [.pickerScorecard, .pickPathPicker, .preSubOOSItem]
    }

    /// Rows that belong in a seat sqlite. Company thin drops shopper tape.
    static func scopeRows(
        _ rows: [MetricRow],
        roster: [String: HeartbeatMath.StoreIdentity],
        key: Key
    ) -> [MetricRow] {
        if key.grain == .company {
            return rows.filter { !shopperSections().contains($0.section) }
        }
        let allowed = PulseCaches.allowedStores(roster: roster, filters: key.filters) ?? []
        guard !allowed.isEmpty else { return [] }
        return rows.filter { row in
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if store.isEmpty { return false }
            return HeartbeatMath.storeInAllowed(store, allowed: allowed)
        }
    }

    static func sectionStoreCounts(
        _ rows: [MetricRow],
        seatStores: Int
    ) -> [String: Int] {
        var out: [String: Int] = [:]
        for section in MetricSection.dashboardCards {
            let scoped = rows.filter { $0.section == section }
            if section == .pickerScorecard {
                out[section.rawValue] = seatStores
            } else {
                out[section.rawValue] = max(PulseLaunch.hubStoreCardCount(scoped), seatStores)
            }
        }
        return out
    }

    @discardableResult
    static func writeCooked(
        rows: [MetricRow],
        uploads: [UploadRecord],
        key: Key,
        roster: [String: HeartbeatMath.StoreIdentity],
        to dest: URL
    ) throws -> Entry {
        let scoped = scopeRows(rows, roster: roster, key: key)
        let grain = key.dashboardGrain
        let caches = PulseCaches.build(
            rows: scoped,
            filters: key.filters,
            uploads: uploads,
            heavy: key.grain != .company,
            grain: grain
        )
        var chrome = PulseDashChrome.from(caches, grain: grain)
        let seatN = (PulseCaches.allowedStores(
            roster: caches.roster.isEmpty ? roster : caches.roster,
            filters: key.filters
        ) ?? Set((caches.roster.isEmpty ? roster : caches.roster).keys)).count
        if key.grain != .company, seatN > 0 {
            chrome.summaries = chrome.summaries.map { PulseLaunch.pinSeatStoreCount($0, seatStores: seatN) }
        }
        try PulseSQLite.write(rows: scoped, uploads: uploads, seeded: true, chrome: chrome, to: dest)
        let bytes = PulseSQLite.fileBytes(at: dest)
        return Entry(
            grain: key.grain.rawValue,
            id: key.slug,
            path: key.objectPath,
            storeCount: key.grain == .company ? caches.roster.count : seatN,
            bytes: bytes,
            sectionStoreCounts: sectionStoreCounts(scoped, seatStores: max(seatN, caches.roster.count))
        )
    }

    /// Device fallback when the published seat object is not on disk yet.
    /// SQL `readStores` → new sqlite. Not an in-memory market slice.
    static func materialize(
        from company: URL,
        key: Key,
        roster: [String: HeartbeatMath.StoreIdentity],
        uploads: [UploadRecord],
        to dest: URL
    ) throws -> Entry {
        var roster = roster
        let sourceRows: [MetricRow]
        if roster.isEmpty {
            let pack = try PulseSQLite.read(from: company)
            roster = PulseCaches.storeRoster(from: pack.rows)
            sourceRows = pack.rows
        } else if key.grain == .company {
            let pack = try PulseSQLite.read(from: company)
            sourceRows = pack.rows
            if roster.isEmpty { roster = pack.rows.isEmpty ? [:] : PulseCaches.storeRoster(from: pack.rows) }
        } else {
            let allowed = PulseCaches.allowedStores(roster: roster, filters: key.filters) ?? []
            sourceRows = PulseSQLite.readStores(
                from: company,
                sections: Set(MetricSection.allCases),
                stores: allowed
            )
        }
        return try writeCooked(rows: sourceRows, uploads: uploads, key: key, roster: roster, to: dest)
    }

    static func publishedDistrictKeys(roster: [String: HeartbeatMath.StoreIdentity]) -> [Key] {
        let ids = Set(roster.values.map { HeartbeatMath.canonicalDistrict($0.district) })
            .filter { !$0.isEmpty }
            .sorted()
        return ids.map { Key(grain: .district, id: $0) }
    }

    static func publishedStoreKeys(roster: [String: HeartbeatMath.StoreIdentity]) -> [Key] {
        roster.keys
            .map { HeartbeatMath.canonicalStore($0) }
            .filter { !$0.isEmpty }
            .sorted(by: HeartbeatFormat.storeOrder)
            .map { Key(grain: .store, id: $0) }
    }

    static func cookPublished(
        rows: [MetricRow],
        uploads: [UploadRecord],
        packRoot: URL,
        includeStores: Bool
    ) throws -> Manifest {
        let roster = PulseCaches.storeRoster(from: rows)
        try FileManager.default.createDirectory(at: packRoot, withIntermediateDirectories: true)
        let companyDest = localURL(root: packRoot.deletingLastPathComponent(), key: .company)
        try FileManager.default.createDirectory(at: companyDest.deletingLastPathComponent(), withIntermediateDirectories: true)
        let company = try writeCooked(
            rows: rows,
            uploads: uploads,
            key: .company,
            roster: roster,
            to: companyDest
        )
        var districts: [Entry] = []
        for key in publishedDistrictKeys(roster: roster) {
            let dest = localURL(root: packRoot.deletingLastPathComponent(), key: key)
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            districts.append(try writeCooked(rows: rows, uploads: uploads, key: key, roster: roster, to: dest))
        }
        var stores: [Entry] = []
        if includeStores {
            for key in publishedStoreKeys(roster: roster) {
                let dest = localURL(root: packRoot.deletingLastPathComponent(), key: key)
                try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                stores.append(try writeCooked(rows: rows, uploads: uploads, key: key, roster: roster, to: dest))
            }
        }
        let manifest = Manifest(
            schema: schemaVersion,
            stamp: BuildStamp.id,
            cookedAt: ISO8601DateFormatter().string(from: Date()),
            company: company,
            districts: districts,
            stores: stores
        )
        let manifestURL = packRoot.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        return manifest
    }
}
