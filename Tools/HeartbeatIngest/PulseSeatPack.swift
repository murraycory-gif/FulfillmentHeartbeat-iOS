import Foundation

/// Kitchen seat plane. The phone target does not compile this file.
/// Field devices keep failing closed when a seat sqlite is missing.
enum PulseSeatPack {
    static let schemaVersion = 1
    /// A seat file under this size is not a pack the phone will open.
    static let minimumSeatBytes = 2_000

    /// Mac cook always writes every roster store, plus district and OM seats.
    static func shouldCookEveryStoreSeat() -> Bool { true }

    enum Grain: String, Codable, CaseIterable {
        case company
        case district
        case om
        case store
    }

    struct Key: Hashable, Codable, Equatable {
        var grain: Grain
        var id: String

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
            case .om:
                next.om = id
            case .store:
                next.store = id
            }
            return next
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
        var oms: [Entry]
        var stores: [Entry]
    }

    struct CookError: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    static func localURL(root: URL, key: Key) -> URL {
        root
            .appendingPathComponent("packs", isDirectory: true)
            .appendingPathComponent("seat", isDirectory: true)
            .appendingPathComponent(key.grain.rawValue, isDirectory: true)
            .appendingPathComponent(key.slug, isDirectory: true)
            .appendingPathComponent("current.sqlite")
    }

    /// Two-or-more letter tokens, no digits. `NorCal 04` / `Chicago 1` are areas.
    static func isPublishedOMPerson(_ raw: String) -> Bool {
        let name = HeartbeatMath.canonicalOM(raw)
        guard !name.isEmpty else { return false }
        if name.unicodeScalars.contains(where: { CharacterSet.decimalDigits.contains($0) }) {
            return false
        }
        let tokens = name.split { $0.isWhitespace || $0 == "/" }.filter { token in
            token.contains(where: \.isLetter)
        }
        return tokens.count >= 2
    }

    static func publishedDistrictKeys(roster: [String: HeartbeatMath.StoreIdentity]) -> [Key] {
        let ids = Set(roster.values.map { HeartbeatMath.canonicalDistrict($0.district) })
            .filter { !$0.isEmpty }
            .sorted()
        return ids.map { Key(grain: .district, id: $0) }
    }

    static func publishedOMKeys(roster: [String: HeartbeatMath.StoreIdentity]) -> [Key] {
        var seen: [String: String] = [:]
        for identity in roster.values {
            let om = HeartbeatMath.canonicalOM(identity.om)
            guard isPublishedOMPerson(om) else { continue }
            let key = om.lowercased()
            if seen[key] == nil { seen[key] = om }
        }
        return seen.values.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { Key(grain: .om, id: $0) }
    }

    static func publishedStoreKeys(roster: [String: HeartbeatMath.StoreIdentity]) -> [Key] {
        roster.keys
            .map { HeartbeatMath.canonicalStore($0) }
            .filter { !$0.isEmpty }
            .sorted(by: HeartbeatFormat.storeOrder)
            .map { Key(grain: .store, id: $0) }
    }

    /// Writes `packs/seat/{district,om,store}/<id>/current.sqlite` beside the market file.
    /// The company seat is not this fat market sqlite. The workflow copies the
    /// thinned `current.sqlite` onto `packs/seat/company/all/` after the 40MB gate.
    static func cookPublished(
        rows: [MetricRow],
        uploads: [UploadRecord],
        packRoot: URL,
        includeStores: Bool
    ) throws -> Manifest {
        let roster = PulseCaches.storeRoster(from: rows)
        let root = packRoot.deletingLastPathComponent()
        var byStore: [String: [MetricRow]] = [:]
        byStore.reserveCapacity(max(roster.count, 1))
        for row in rows {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            byStore[store, default: []].append(row)
        }

        let districtKeys = publishedDistrictKeys(roster: roster)
        let omKeys = publishedOMKeys(roster: roster)
        let storeKeys = includeStores ? publishedStoreKeys(roster: roster) : []
        if includeStores && storeKeys.isEmpty {
            throw CookError(message: "COOK FAILED: roster has zero stores. Refusing a company-only pack.")
        }

        log("Seat cook roster stores=\(roster.count) districts=\(districtKeys.count) oms=\(omKeys.count) storePacks=\(storeKeys.count)")
        let districts = try writeAll(districtKeys, rowsByStore: byStore, uploads: uploads, roster: roster, root: root, label: "district")
        let oms = try writeAll(omKeys, rowsByStore: byStore, uploads: uploads, roster: roster, root: root, label: "OM")
        let stores = try writeAll(storeKeys, rowsByStore: byStore, uploads: uploads, roster: roster, root: root, label: "store")
        if includeStores && stores.isEmpty {
            throw CookError(message: "COOK FAILED: wrote zero store seat packs.")
        }

        let company = Entry(
            grain: Grain.company.rawValue,
            id: "all",
            path: "packs/seat/company/all/current.sqlite",
            storeCount: roster.count,
            bytes: 0,
            sectionStoreCounts: [:]
        )
        let manifest = Manifest(
            schema: schemaVersion,
            stamp: BuildStamp.id,
            cookedAt: ISO8601DateFormatter().string(from: Date()),
            company: company,
            districts: districts,
            oms: oms,
            stores: stores
        )
        try FileManager.default.createDirectory(at: packRoot, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestURL = packRoot.appendingPathComponent("manifest.json")
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        log("Seat packs districts=\(districts.count) oms=\(oms.count) stores=\(stores.count)")
        return manifest
    }

    private static func writeAll(
        _ keys: [Key],
        rowsByStore: [String: [MetricRow]],
        uploads: [UploadRecord],
        roster: [String: HeartbeatMath.StoreIdentity],
        root: URL,
        label: String
    ) throws -> [Entry] {
        var entries: [Entry] = []
        entries.reserveCapacity(keys.count)
        for (index, key) in keys.enumerated() {
            entries.append(try writeSeat(
                key: key,
                rowsByStore: rowsByStore,
                uploads: uploads,
                roster: roster,
                root: root
            ))
            let done = index + 1
            if done == keys.count || done % 100 == 0 {
                log("  \(label) seats \(done)/\(keys.count)")
            }
        }
        return entries
    }

    private static func writeSeat(
        key: Key,
        rowsByStore: [String: [MetricRow]],
        uploads: [UploadRecord],
        roster: [String: HeartbeatMath.StoreIdentity],
        root: URL
    ) throws -> Entry {
        let stores = seatStores(key: key, roster: roster)
        var scoped: [MetricRow] = []
        scoped.reserveCapacity(stores.count * 8)
        for store in stores.sorted(by: HeartbeatFormat.storeOrder) {
            if let slice = rowsByStore[store] {
                scoped.append(contentsOf: slice)
            }
        }
        let caches = PulseCaches.build(
            rows: scoped,
            filters: key.filters,
            uploads: uploads,
            heavy: true,
            grain: .store
        )
        let chrome = PulseDashChrome.from(caches)
        let dest = localURL(root: root, key: key)
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PulseSQLite.write(rows: scoped, uploads: uploads, seeded: true, chrome: chrome, to: dest)
        let bytes = fileBytes(dest)
        if bytes < minimumSeatBytes {
            throw CookError(message: "COOK FAILED: \(key.objectPath) is \(bytes) bytes, under \(minimumSeatBytes).")
        }
        return Entry(
            grain: key.grain.rawValue,
            id: key.slug,
            path: key.objectPath,
            storeCount: stores.count,
            bytes: bytes,
            sectionStoreCounts: sectionStoreCounts(scoped, seatStores: stores.count)
        )
    }

    private static func seatStores(
        key: Key,
        roster: [String: HeartbeatMath.StoreIdentity]
    ) -> Set<String> {
        if let allowed = PulseCaches.allowedStores(roster: roster, filters: key.filters), !allowed.isEmpty {
            return allowed
        }
        if key.grain == .store {
            let store = HeartbeatMath.canonicalStore(key.id)
            if !store.isEmpty { return [store] }
        }
        return []
    }

    private static func sectionStoreCounts(_ rows: [MetricRow], seatStores: Int) -> [String: Int] {
        var out: [String: Int] = [:]
        for section in MetricSection.dashboardCards {
            if section == .pickerScorecard {
                out[section.rawValue] = seatStores
                continue
            }
            var stores = Set<String>()
            for row in rows where row.section == section {
                let store = HeartbeatMath.canonicalStore(row.storeNumber)
                if !store.isEmpty { stores.insert(store) }
            }
            out[section.rawValue] = stores.count
        }
        return out
    }

    private static func fileBytes(_ url: URL) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    }

    private static func log(_ message: String) {
        print(message)
    }
}
