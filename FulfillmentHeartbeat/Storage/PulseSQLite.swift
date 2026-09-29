import Foundation
import SQLite3

/// On-device Heartbeat pack. Excel is ingest only after a successful load.
enum PulseSQLite {
    static let schemaVersion = 1
    static let fileName = "heartbeat.sqlite"

    struct Pack {
        var rows: [MetricRow]
        var uploads: [UploadRecord]
        var seeded: Bool
        var counts: [String: Int]
        var writtenAt: Date?
        var chrome: PulseDashChrome?
    }

    static func write(
        rows: [MetricRow],
        uploads: [UploadRecord],
        seeded: Bool,
        chrome: PulseDashChrome? = nil,
        writtenAt: Date? = nil,
        preSubTops: [String: [PreSubTopItems.Item]]? = nil,
        to url: URL
    ) throws {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let temp = folder.appendingPathComponent("heartbeat-write-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: temp) }
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(temp.path, &db, flags, nil) == SQLITE_OK, let db else {
            throw PulseSQLError.open
        }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, "PRAGMA journal_mode=OFF;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
        sqlite3_exec(db, "BEGIN IMMEDIATE;", nil, nil, nil)
        guard sqlite3_exec(db, Self.ddl, nil, nil, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw PulseSQLError.schema
        }

        var insert: OpaquePointer?
        defer { sqlite3_finalize(insert) }
        guard sqlite3_prepare_v2(db, Self.insertSQL, -1, &insert, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw PulseSQLError.prepare
        }

        var counts: [String: Int] = [:]
        for row in rows {
            sqlite3_reset(insert)
            sqlite3_clear_bindings(insert)
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            bind(insert, 1, row.id.uuidString)
            bind(insert, 2, row.section.rawValue)
            bind(insert, 3, store.isEmpty ? row.storeNumber : store)
            bind(insert, 4, row.division)
            bind(insert, 5, row.operationsOM)
            bind(insert, 6, row.storeName)
            bind(insert, 7, row.recordedOn)
            bind(insert, 8, encodeMap(row.payload))
            bind(insert, 9, encodeText(row.textPayload))
            bind(insert, 10, HeartbeatMath.health(for: row.section, row: row).needsAction ? 1 : 0)
            guard sqlite3_step(insert) == SQLITE_DONE else {
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw PulseSQLError.insert
            }
            counts[row.section.rawValue, default: 0] += 1
        }

        let metaSQL = """
        INSERT INTO pack_meta(id, schema_version, seeded, written_at, uploads_json, counts_json)
        VALUES (1, ?, ?, ?, ?, ?);
        """
        var meta: OpaquePointer?
        defer { sqlite3_finalize(meta) }
        guard sqlite3_prepare_v2(db, metaSQL, -1, &meta, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw PulseSQLError.prepare
        }
        sqlite3_bind_int(meta, 1, Int32(schemaVersion))
        sqlite3_bind_int(meta, 2, seeded ? 1 : 0)
        bind(meta, 3, ISO8601DateFormatter().string(from: writtenAt ?? Date()))
        bind(meta, 4, encodeUploads(uploads))
        bind(meta, 5, encodeText(counts.mapValues { String($0) }))
        guard sqlite3_step(meta) == SQLITE_DONE else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw PulseSQLError.insert
        }
        if let chrome {
            writeChrome(chrome, db: db)
            writeSummaryCards(chrome, db: db)
        }
        if let preSubTops {
            writePreSubTops(preSubTops, db: db)
        }
        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: temp, to: url)
    }

    /// Full-file fact decodes. A filter change must leave this at 0.
    static var companyFactReadCount = 0
    /// `readSection` walks a section with no store filter. Company pages must leave this at 0.
    static var sectionFactReadCount = 0
    /// Rows decoded into `MetricRow`, payloads included. Filter tests use this
    /// to prove a store query did not materialize the rest of the company.
    static var decodedFactRowCount = 0

    static func read(from url: URL, skipping skip: Set<MetricSection> = [], only: Set<MetricSection> = []) throws -> Pack {
        companyFactReadCount += 1
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            throw PulseSQLError.open
        }
        defer { sqlite3_close(db) }

        #if canImport(UIKit) && !HEARTBEAT_INGEST
        let lowMemory = HubLayout.lightLaunch
        #else
        let lowMemory = false
        #endif
        sqlite3_exec(db, lowMemory ? "PRAGMA mmap_size=33554432;" : "PRAGMA mmap_size=268435456;", nil, nil, nil)
        sqlite3_exec(db, lowMemory ? "PRAGMA cache_size=-2000;" : "PRAGMA cache_size=-8000;", nil, nil, nil)

        var metaStmt: OpaquePointer?
        defer { sqlite3_finalize(metaStmt) }
        var seeded = true
        var writtenAt: Date?
        var uploads: [UploadRecord] = []
        if sqlite3_prepare_v2(db, "SELECT schema_version, seeded, written_at, uploads_json FROM pack_meta WHERE id = 1;", -1, &metaStmt, nil) == SQLITE_OK,
           sqlite3_step(metaStmt) == SQLITE_ROW {
            let version = Int(sqlite3_column_int(metaStmt, 0))
            guard version == schemaVersion else { throw PulseSQLError.schema }
            seeded = sqlite3_column_int(metaStmt, 1) == 1
            if let raw = sqlite3_column_text(metaStmt, 2) {
                writtenAt = ISO8601DateFormatter().date(from: String(cString: raw))
            }
            if let raw = sqlite3_column_text(metaStmt, 3) {
                uploads = decodeUploads(String(cString: raw))
            }
        }

        let sql: String
        if !only.isEmpty {
            let list = only.map { "'\($0.rawValue)'" }.joined(separator: ",")
            sql = "SELECT id, section, store_number, division, operations_om, store_name, recorded_on, payload_json, text_json FROM facts WHERE section IN (\(list));"
        } else if skip.isEmpty {
            sql = "SELECT id, section, store_number, division, operations_om, store_name, recorded_on, payload_json, text_json FROM facts;"
        } else {
            let list = skip.map { "'\($0.rawValue)'" }.joined(separator: ",")
            sql = "SELECT id, section, store_number, division, operations_om, store_name, recorded_on, payload_json, text_json FROM facts WHERE section NOT IN (\(list));"
        }

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw PulseSQLError.prepare }

        var rows: [MetricRow] = []
        rows.reserveCapacity(8_192)
        var counts: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let row = metricRow(stmt) else { continue }
            rows.append(row)
            counts[row.section.rawValue, default: 0] += 1
        }
        let chrome = readChrome(db: db)
        return Pack(rows: rows, uploads: uploads, seeded: seeded, counts: counts, writtenAt: writtenAt, chrome: chrome)
    }

    /// Page-open path: one section, a slice at a time, so Picker can paint the first shoppers.
    static func readSection(
        from url: URL,
        section: MetricSection,
        limit: Int,
        offset: Int = 0
    ) -> [MetricRow] {
        sectionFactReadCount += 1
        guard exists(at: url), limit > 0, offset >= 0 else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return []
        }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, "PRAGMA mmap_size=33554432;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size=-2000;", nil, nil, nil)
        let sql = """
        SELECT id, section, store_number, division, operations_om, store_name, recorded_on, payload_json, text_json
        FROM facts WHERE section = ? ORDER BY rowid LIMIT ? OFFSET ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, section.rawValue)
        bind(stmt, 2, limit)
        bind(stmt, 3, offset)
        var out: [MetricRow] = []
        out.reserveCapacity(min(limit, 256))
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let row = metricRow(stmt) {
                out.append(row)
            }
        }
        return out
    }

    /// Filter path: pull only the stores in the current filter from the pack.
    static func readStores(
        from url: URL,
        sections: Set<MetricSection>,
        stores: Set<String>
    ) -> [MetricRow] {
        guard !sections.isEmpty, !stores.isEmpty, exists(at: url) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return []
        }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, "PRAGMA mmap_size=33554432;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size=-4000;", nil, nil, nil)

        var keys: [String] = []
        var seen: Set<String> = []
        for store in stores {
            for alias in HeartbeatMath.storeAliases(store) where seen.insert(alias).inserted {
                keys.append(alias)
            }
        }
        guard !keys.isEmpty else { return [] }

        var out: [MetricRow] = []
        out.reserveCapacity(max(stores.count * 2, 32))
        let sectionList = Array(sections)
        let chunkSize = 180
        var start = 0
        while start < keys.count {
            let end = min(start + chunkSize, keys.count)
            let slice = Array(keys[start..<end])
            start = end
            let sectionMarks = Array(repeating: "?", count: sectionList.count).joined(separator: ",")
            let storeMarks = Array(repeating: "?", count: slice.count).joined(separator: ",")
            let sql = """
            SELECT id, section, store_number, division, operations_om, store_name, recorded_on, payload_json, text_json
            FROM facts
            WHERE section IN (\(sectionMarks)) AND store_number IN (\(storeMarks));
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { continue }
            defer { sqlite3_finalize(stmt) }
            var index: Int32 = 1
            for section in sectionList {
                bind(stmt, index, section.rawValue)
                index += 1
            }
            for key in slice {
                bind(stmt, index, key)
                index += 1
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let row = metricRow(stmt) {
                    out.append(row)
                }
            }
        }

        let found = Set(out.map(\.section))
        let light: Set<MetricSection> = [
            .sales, .lostRevenue, .fiveStar, .labor, .missingItems, .preSubOOS,
            .pickPath, .aisleMapper, .prepNotReady, .dynacap, .scheduleQuality, .pph
        ]
        for section in sections where light.contains(section) && !found.contains(section) {
            out.append(contentsOf: rowsMatchingSection(db: db, section: section, stores: stores))
        }
        return out
    }

    /// How many store numbers are in the file, without decoding payloads.
    static func distinctStoreCount(from url: URL) -> Int {
        guard exists(at: url) else { return 0 }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return 0
        }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, "PRAGMA mmap_size=0;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size=-500;", nil, nil, nil)
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(
            db,
            "SELECT COUNT(DISTINCT store_number) FROM facts WHERE store_number != '';",
            -1,
            &stmt,
            nil
        ) == SQLITE_OK else { return 0 }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    /// Picker list. Store number, division, OM, and name only — never `payload_json`.
    /// Roster rows also contribute district from `text_json`, which is one small row per store.
    static func readStoreIndex(from url: URL) -> [String: HeartbeatMath.StoreIdentity] {
        guard exists(at: url) else { return [:] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return [:]
        }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, "PRAGMA mmap_size=0;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size=-2000;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA query_only=ON;", nil, nil, nil)

        var index: [String: HeartbeatMath.StoreIdentity] = [:]
        mergeRosterIdentities(db: db, into: &index)
        mergeColumnIdentities(db: db, into: &index)
        return index
    }

    private static func mergeRosterIdentities(
        db: OpaquePointer,
        into index: inout [String: HeartbeatMath.StoreIdentity]
    ) {
        var stmt: OpaquePointer?
        let sql = """
        SELECT store_number, division, operations_om, store_name, text_json
        FROM facts WHERE section = ?;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, MetricSection.storeRoster.rawValue)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let number = HeartbeatMath.canonicalStore(string(stmt, 0))
            guard !number.isEmpty, !HeartbeatMath.isIgnoredStore(number) else { continue }
            let text = decodeText(optional(stmt, 4) ?? "{}")
            var identity = index[number] ?? HeartbeatMath.StoreIdentity(division: "", district: "", om: "", name: nil)
            let division = MarketRegion.canonicalName(string(stmt, 1))
            if !division.isEmpty { identity.division = division }
            let district = HeartbeatMath.canonicalDistrict(text["district"] ?? "")
            if !district.isEmpty { identity.district = district }
            let om = HeartbeatMath.canonicalOM(string(stmt, 2))
            if !om.isEmpty { identity.om = om }
            if let name = optional(stmt, 3), !name.isEmpty { identity.name = name }
            index[number] = identity
        }
    }

    private static func mergeColumnIdentities(
        db: OpaquePointer,
        into index: inout [String: HeartbeatMath.StoreIdentity]
    ) {
        var stmt: OpaquePointer?
        let sql = """
        SELECT store_number,
               MAX(CASE WHEN division IS NOT NULL AND division != '' THEN division END),
               MAX(CASE WHEN operations_om IS NOT NULL AND operations_om != '' THEN operations_om END),
               MAX(CASE WHEN store_name IS NOT NULL AND store_name != '' THEN store_name END)
        FROM facts
        WHERE store_number != ''
        GROUP BY store_number;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            let number = HeartbeatMath.canonicalStore(string(stmt, 0))
            guard !number.isEmpty, !HeartbeatMath.isIgnoredStore(number), index[number] == nil else { continue }
            let name = optional(stmt, 3)
            index[number] = HeartbeatMath.StoreIdentity(
                division: MarketRegion.canonicalName(string(stmt, 1)),
                district: "",
                om: HeartbeatMath.canonicalOM(string(stmt, 2)),
                name: (name?.isEmpty == false) ? name : nil
            )
        }
    }

    /// A store number the `IN` list missed (padding, a trailing decimal). SQLite returns
    /// only the matching rows, so the rest of the company file stays out of Swift.
    private static func rowsMatchingSection(
        db: OpaquePointer,
        section: MetricSection,
        stores: Set<String>
    ) -> [MetricRow] {
        var ints: [Int] = []
        var seenInt = Set<Int>()
        for store in stores {
            let canonical = HeartbeatMath.canonicalStore(store)
            if let value = Int(canonical), value > 0, seenInt.insert(value).inserted {
                ints.append(value)
            }
        }
        var pool: [MetricRow] = []
        let chunkSize = 180
        var start = 0
        while start < ints.count {
            let end = min(start + chunkSize, ints.count)
            let slice = Array(ints[start..<end])
            start = end
            let marks = Array(repeating: "?", count: slice.count).joined(separator: ",")
            let sql = """
            SELECT id, section, store_number, division, operations_om, store_name, recorded_on, payload_json, text_json
            FROM facts
            WHERE section = ? AND CAST(store_number AS INTEGER) IN (\(marks))
              AND CAST(store_number AS INTEGER) != 0;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { continue }
            defer { sqlite3_finalize(stmt) }
            bind(stmt, 1, section.rawValue)
            for (offset, value) in slice.enumerated() {
                bind(stmt, Int32(offset + 2), value)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let row = metricRow(stmt) {
                    pool.append(row)
                }
            }
        }
        if section == .dynacap || section == .scheduleQuality {
            pool.append(contentsOf: emptyStoreRows(db: db, section: section))
        }
        guard !pool.isEmpty else { return [] }
        return PulseCaches.rowsMatchingStores(pool, stores: stores, skipMarket: true)
    }

    private static func emptyStoreRows(db: OpaquePointer, section: MetricSection) -> [MetricRow] {
        var stmt: OpaquePointer?
        let sql = """
        SELECT id, section, store_number, division, operations_om, store_name, recorded_on, payload_json, text_json
        FROM facts WHERE section = ? AND store_number = '' LIMIT 40;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, section.rawValue)
        var out: [MetricRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let row = metricRow(stmt) {
                out.append(row)
            }
        }
        return out
    }

    private static func metricRow(_ stmt: OpaquePointer?) -> MetricRow? {
        guard let stmt else { return nil }
        decodedFactRowCount += 1
        let sectionRaw = string(stmt, 1)
        guard let section = MetricSection(rawValue: sectionRaw) else { return nil }
        let rawStore = string(stmt, 2)
        let store = HeartbeatMath.canonicalStore(rawStore)
        return MetricRow(
            id: UUID(uuidString: string(stmt, 0)) ?? UUID(),
            section: section,
            division: string(stmt, 3),
            operationsOM: string(stmt, 4),
            storeNumber: store.isEmpty ? rawStore : store,
            storeName: optional(stmt, 5),
            recordedOn: optional(stmt, 6),
            payload: decodeMap(optional(stmt, 7) ?? "{}"),
            textPayload: decodeText(optional(stmt, 8) ?? "{}")
        )
    }

    static func exists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path) && fileBytes(at: url) > 500
    }

    static func fileBytes(at url: URL) -> Int {
        PulseLaunch.fileBytes(at: url)
    }

    static func isUsableFile(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
            && PulseLaunch.isUsableFileSize(fileBytes(at: url))
    }

    /// Sales week (`YYYYWW`) from the first store sales row. Empty if the pack has none.
    static func salesWeek(at url: URL) -> String {
        guard FileManager.default.fileExists(atPath: url.path) else { return "" }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return ""
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        let sql = "SELECT text_json, recorded_on FROM facts WHERE section = 'sales' LIMIT 40;"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return ""
        }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            if let raw = sqlite3_column_text(statement, 0) {
                let text = decodeText(String(cString: raw))
                if let week = text["sales_week"], PulseLiveSource.weekRank(week) != nil {
                    return week
                }
            }
            if let raw = sqlite3_column_text(statement, 1) {
                let recorded = String(cString: raw)
                if PulseLiveSource.weekRank(recorded) != nil { return recorded }
            }
        }
        return ""
    }

    /// ISO-8601 `pack_meta.written_at` from a local sqlite. Empty if missing or unreadable.
    static func writtenAtString(at url: URL) -> String {
        guard FileManager.default.fileExists(atPath: url.path) else { return "" }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return ""
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        let sql = "SELECT written_at FROM pack_meta WHERE id = 1 LIMIT 1;"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return ""
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return "" }
        guard let cString = sqlite3_column_text(statement, 0) else { return "" }
        return String(cString: cString)
    }

    /// Reported vs in-scope Prep stores. One grouped query. Does not decode fact rows.
    static func prepCoverage(from url: URL) -> HeartbeatMath.PrepCoverage? {
        guard exists(at: url) else { return nil }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return nil
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = """
        SELECT store_number,
               MAX(CASE
                   WHEN instr(payload_json, '"pnr_rate_pct"') > 0
                     OR instr(payload_json, '"pnr_hours"') > 0
                     OR instr(payload_json, '"prep_not_ready_pct"') > 0
                   THEN 1 ELSE 0 END)
        FROM facts
        WHERE section = ?
        GROUP BY store_number;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        bind(stmt, 1, MetricSection.prepNotReady.rawValue)
        var inScope = 0
        var reported = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let store = string(stmt, 0)
            guard !store.isEmpty, !HeartbeatMath.isIgnoredStore(store) else { continue }
            inScope += 1
            if sqlite3_column_int(stmt, 1) != 0 { reported += 1 }
        }
        guard inScope > 0 else { return nil }
        return HeartbeatMath.PrepCoverage(reported: reported, inScope: inScope)
    }

    /// One section's store payloads for region cards. Does not call `metricRow`
    /// and does not bump fact counters, so company install stays off the fact plane.
    struct GrainFact: Equatable {
        var store: String
        var division: String
        var numbers: [String: Double]
        var text: [String: String]
    }

    static func readGrainFacts(from url: URL, section: MetricSection) -> [GrainFact] {
        guard exists(at: url) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return []
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = """
        SELECT store_number, division, payload_json, text_json
        FROM facts
        WHERE section = ?;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        bind(stmt, 1, section.rawValue)
        var out: [GrainFact] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(GrainFact(
                store: string(stmt, 0),
                division: string(stmt, 1),
                numbers: decodeMap(optional(stmt, 2) ?? "{}"),
                text: decodeText(optional(stmt, 3) ?? "{}")
            ))
        }
        return out
    }

    /// One row per store. Not a `LIMIT` walk of `facts_section_div` (that prefix
    /// is Haggen, then Jewel, then a slice of Mid-Atlantic — everyone else is 0).
    static func pickerHeadcounts(from url: URL) -> [String: Int] {
        guard exists(at: url) else { return [:] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return [:]
        }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, "PRAGMA mmap_size=33554432;", nil, nil, nil)
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = """
        SELECT store_number, COUNT(*)
        FROM facts
        WHERE section = ?
        GROUP BY store_number;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        bind(stmt, 1, MetricSection.pickerScorecard.rawValue)
        var raw: [String: Int] = [:]
        raw.reserveCapacity(2_200)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let store = string(stmt, 0)
            let count = Int(sqlite3_column_int64(stmt, 1))
            guard !store.isEmpty, count > 0 else { continue }
            raw[store, default: 0] += count
        }
        return raw
    }

    static func sectionCount(from url: URL, section: MetricSection) -> Int {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return 0
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM facts WHERE section = ?;", -1, &stmt, nil) == SQLITE_OK else {
            return 0
        }
        bind(stmt, 1, section.rawValue)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private static let ddl = """
    CREATE TABLE pack_meta (
        id INTEGER PRIMARY KEY,
        schema_version INTEGER NOT NULL,
        seeded INTEGER NOT NULL,
        written_at TEXT,
        uploads_json TEXT,
        counts_json TEXT
    );
    CREATE TABLE facts (
        id TEXT PRIMARY KEY,
        section TEXT NOT NULL,
        store_number TEXT NOT NULL,
        division TEXT,
        operations_om TEXT,
        store_name TEXT,
        recorded_on TEXT,
        payload_json TEXT,
        text_json TEXT,
        needs_attention INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX facts_section_store ON facts(section, store_number);
    CREATE INDEX facts_store ON facts(store_number);
    CREATE INDEX facts_section_div ON facts(section, division);
    CREATE INDEX facts_attention ON facts(section, store_number) WHERE needs_attention = 1;
    CREATE VIEW detail_facts AS
        SELECT store_number AS store_id, section, needs_attention, payload_json, text_json
        FROM facts;
    CREATE TABLE dash_chrome (
        id INTEGER PRIMARY KEY,
        json TEXT NOT NULL
    );
    CREATE TABLE summary_cards (
        section TEXT PRIMARY KEY,
        store_count INTEGER NOT NULL,
        headline REAL,
        json TEXT NOT NULL
    );
    CREATE TABLE schedule_pack (
        id INTEGER PRIMARY KEY,
        published_at TEXT NOT NULL,
        week INTEGER NOT NULL,
        filename TEXT NOT NULL,
        summary_title TEXT NOT NULL,
        workbook_action_banner INTEGER
    );
    CREATE TABLE schedule_market (
        label TEXT PRIMARY KEY,
        under REAL,
        over REAL,
        eff REAL
    );
    CREATE TABLE schedule_store (
        store TEXT PRIMARY KEY,
        region TEXT NOT NULL,
        division TEXT NOT NULL,
        district TEXT NOT NULL,
        om TEXT NOT NULL,
        sales REAL,
        under REAL,
        over REAL,
        eff REAL,
        pch REAL,
        four_under REAL,
        four_over REAL,
        star REAL,
        day_under_json TEXT NOT NULL,
        day_over_json TEXT NOT NULL
    );
    """

    /// Schedule Check rows inside an existing pack. Safe on a file that predates the tables.
    static let scheduleDDL = """
    CREATE TABLE IF NOT EXISTS schedule_pack (
        id INTEGER PRIMARY KEY,
        published_at TEXT NOT NULL,
        week INTEGER NOT NULL,
        filename TEXT NOT NULL,
        summary_title TEXT NOT NULL,
        workbook_action_banner INTEGER
    );
    CREATE TABLE IF NOT EXISTS schedule_market (
        label TEXT PRIMARY KEY,
        under REAL,
        over REAL,
        eff REAL
    );
    CREATE TABLE IF NOT EXISTS schedule_store (
        store TEXT PRIMARY KEY,
        region TEXT NOT NULL,
        division TEXT NOT NULL,
        district TEXT NOT NULL,
        om TEXT NOT NULL,
        sales REAL,
        under REAL,
        over REAL,
        eff REAL,
        pch REAL,
        four_under REAL,
        four_over REAL,
        star REAL,
        day_under_json TEXT NOT NULL,
        day_over_json TEXT NOT NULL
    );
    """

    private static let insertSQL = """
    INSERT INTO facts(id, section, store_number, division, operations_om, store_name, recorded_on, payload_json, text_json, needs_attention)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    private static func writeChrome(_ chrome: PulseDashChrome, db: OpaquePointer) {
        sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS dash_chrome (id INTEGER PRIMARY KEY, json TEXT NOT NULL);", nil, nil, nil)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(chrome),
              let json = String(data: data, encoding: .utf8)
        else { return }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO dash_chrome(id, json) VALUES (1, ?);", -1, &stmt, nil) == SQLITE_OK else {
            return
        }
        bind(stmt, 1, json)
        _ = sqlite3_step(stmt)
    }

    private static func writeSummaryCards(_ chrome: PulseDashChrome, db: OpaquePointer) {
        sqlite3_exec(
            db,
            "CREATE TABLE IF NOT EXISTS summary_cards (section TEXT PRIMARY KEY, store_count INTEGER NOT NULL, headline REAL, json TEXT NOT NULL);",
            nil, nil, nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(
            db,
            "INSERT OR REPLACE INTO summary_cards(section, store_count, headline, json) VALUES (?, ?, ?, ?);",
            -1, &stmt, nil
        ) == SQLITE_OK else { return }
        for card in chrome.summaries {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            bind(stmt, 1, card.section.rawValue)
            sqlite3_bind_int(stmt, 2, Int32(card.storeCount))
            if let headline = card.headline {
                sqlite3_bind_double(stmt, 3, headline)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            let json = (try? encoder.encode(card)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            bind(stmt, 4, json)
            _ = sqlite3_step(stmt)
        }
    }

    /// VACUUM after cook so a District pack stays in the 5–10 MB band.
    static func compact(at url: URL) {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return
        }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, "VACUUM;", nil, nil, nil)
    }

    /// Uses the partial `facts_attention` index. Empty on market packs without the column.
    static func needsAttentionStores(from url: URL, section: MetricSection? = nil) -> [String] {
        guard exists(at: url) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return []
        }
        defer { sqlite3_close(db) }
        let sql: String
        if let section {
            sql = "SELECT DISTINCT store_number FROM facts WHERE needs_attention = 1 AND section = ? ORDER BY store_number;"
        } else {
            sql = "SELECT DISTINCT store_number FROM facts WHERE needs_attention = 1 ORDER BY store_number;"
        }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        if let section {
            bind(stmt, 1, section.rawValue)
        }
        var out: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(string(stmt, 0))
        }
        return out
    }

    static func hasAttentionIndex(at url: URL) -> Bool {
        guard exists(at: url) else { return false }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return false
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(
            db,
            "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = 'facts_attention';",
            -1, &stmt, nil
        ) == SQLITE_OK else { return false }
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    static func hasDetailFactsView(at url: URL) -> Bool {
        guard exists(at: url) else { return false }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return false
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(
            db,
            "SELECT 1 FROM sqlite_master WHERE type = 'view' AND name = 'detail_facts';",
            -1, &stmt, nil
        ) == SQLITE_OK else { return false }
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    /// Partial-index DDL. Empty when the pack predates the addendum.
    static func attentionIndexSQL(at url: URL) -> String {
        objectSQL(at: url, type: "index", name: "facts_attention")
    }

    /// `detail_*` plane keyed `store_id`.
    static func detailStoreIds(from url: URL) -> [String] {
        guard exists(at: url), hasDetailFactsView(at: url) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return []
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(
            db,
            "SELECT DISTINCT store_id FROM detail_facts ORDER BY store_id;",
            -1, &stmt, nil
        ) == SQLITE_OK, let stmt else { return [] }
        var out: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(string(stmt, 0))
        }
        return out
    }

    static func summaryCardCount(from url: URL) -> Int {
        guard exists(at: url) else { return 0 }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return 0
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM summary_cards;", -1, &stmt, nil) == SQLITE_OK else {
            return 0
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private static func objectSQL(at url: URL, type: String, name: String) -> String {
        guard exists(at: url) else { return "" }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return ""
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(
            db,
            "SELECT sql FROM sqlite_master WHERE type = ? AND name = ?;",
            -1, &stmt, nil
        ) == SQLITE_OK else { return "" }
        bind(stmt, 1, type)
        bind(stmt, 2, name)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return "" }
        return string(stmt, 0)
    }

    private static func readChrome(db: OpaquePointer) -> PulseDashChrome? {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT json FROM dash_chrome WHERE id = 1;", -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        guard sqlite3_step(stmt) == SQLITE_ROW, let raw = sqlite3_column_text(stmt, 0) else { return nil }
        let json = String(cString: raw)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(PulseDashChrome.self, from: data)
    }

    /// Workbook Total / market rows only. Does not count as a company fact read.
    static func readCompanyRollupRows(from url: URL) -> [MetricRow] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return []
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        let sql = """
        SELECT id, section, store_number, division, operations_om, store_name, recorded_on, payload_json, text_json
        FROM facts
        WHERE text_json LIKE '%"sales_grain":"company"%'
           OR text_json LIKE '%"lost_grain":"market"%'
           OR text_json LIKE '%"labor_grain":"market"%'
        LIMIT 40;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [MetricRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let row = metricRow(stmt) else { continue }
            switch row.section {
            case .sales:
                if row.textPayload["sales_grain"] == "company" { out.append(row) }
            case .lostRevenue:
                if row.textPayload["lost_grain"] == "market" { out.append(row) }
            case .labor:
                if row.textPayload["labor_grain"] == "market" { out.append(row) }
            default:
                break
            }
        }
        return out
    }

    /// One cooked top-10 list. Does not decode fact rows and does not bump fact counters.
    /// Nil when the `presub_top` table was never cooked. Empty when this scope has no items.
    static func readPreSubTop(from url: URL, scope: String) -> [PreSubTopItems.Item]? {
        guard !scope.isEmpty, exists(at: url) else { return nil }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return nil
        }
        defer { sqlite3_close(db) }
        guard preSubTopTableExists(db) else { return nil }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT json FROM presub_top WHERE scope = ? LIMIT 1;", -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        bind(stmt, 1, scope)
        guard sqlite3_step(stmt) == SQLITE_ROW, let raw = sqlite3_column_text(stmt, 0) else { return [] }
        return decodePreSubItems(String(cString: raw))
    }

    /// Every cooked list. Nil when the table is absent so a rewrite can leave it alone.
    static func readPreSubTops(from url: URL) -> [String: [PreSubTopItems.Item]]? {
        guard exists(at: url) else { return nil }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return nil
        }
        defer { sqlite3_close(db) }
        guard preSubTopTableExists(db) else { return nil }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT scope, json FROM presub_top;", -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        var out: [String: [PreSubTopItems.Item]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let scope = string(stmt, 0)
            guard !scope.isEmpty, let raw = sqlite3_column_text(stmt, 1) else { continue }
            out[scope] = decodePreSubItems(String(cString: raw))
        }
        return out
    }

    private static func preSubTopTableExists(_ db: OpaquePointer) -> Bool {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(
            db,
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'presub_top' LIMIT 1;",
            -1, &stmt, nil
        ) == SQLITE_OK else { return false }
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private static func writePreSubTops(_ lists: [String: [PreSubTopItems.Item]], db: OpaquePointer) {
        sqlite3_exec(
            db,
            "CREATE TABLE IF NOT EXISTS presub_top (scope TEXT PRIMARY KEY, json TEXT NOT NULL);",
            nil, nil, nil
        )
        let encoder = JSONEncoder()
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(
            db,
            "INSERT OR REPLACE INTO presub_top(scope, json) VALUES (?, ?);",
            -1, &stmt, nil
        ) == SQLITE_OK else { return }
        for (scope, items) in lists where !scope.isEmpty {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            let json = (try? encoder.encode(items)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            bind(stmt, 1, scope)
            bind(stmt, 2, json)
            _ = sqlite3_step(stmt)
        }
    }

    private static func decodePreSubItems(_ json: String) -> [PreSubTopItems.Item] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([PreSubTopItems.Item].self, from: data)) ?? []
    }

    /// Schedule Check rows cooked into this sqlite pack. Nil when the tables are absent or empty.
    static func readSchedule(from url: URL) -> ScheduleCheckPack? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return nil
        }
        defer { sqlite3_close(db) }
        var meta: OpaquePointer?
        defer { sqlite3_finalize(meta) }
        guard sqlite3_prepare_v2(
            db,
            "SELECT published_at, week, filename, summary_title, workbook_action_banner FROM schedule_pack WHERE id = 1;",
            -1, &meta, nil
        ) == SQLITE_OK, sqlite3_step(meta) == SQLITE_ROW else {
            return nil
        }
        let publishedAt = string(meta, 0)
        let week = Int(sqlite3_column_int(meta, 1))
        let filename = string(meta, 2)
        let summaryTitle = string(meta, 3)
        let banner: Int? = sqlite3_column_type(meta, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(meta, 4))

        var markets: [ScheduleMarket] = []
        var marketStmt: OpaquePointer?
        defer { sqlite3_finalize(marketStmt) }
        if sqlite3_prepare_v2(db, "SELECT label, under, over, eff FROM schedule_market ORDER BY label;", -1, &marketStmt, nil) == SQLITE_OK {
            while sqlite3_step(marketStmt) == SQLITE_ROW {
                markets.append(ScheduleMarket(
                    label: string(marketStmt, 0),
                    under: optionalDouble(marketStmt, 1),
                    over: optionalDouble(marketStmt, 2),
                    eff: optionalDouble(marketStmt, 3)
                ))
            }
        }

        var stores: [ScheduleStore] = []
        var storeStmt: OpaquePointer?
        defer { sqlite3_finalize(storeStmt) }
        if sqlite3_prepare_v2(
            db,
            """
            SELECT store, region, division, district, om, sales, under, over, eff, pch, four_under, four_over, star, day_under_json, day_over_json
            FROM schedule_store ORDER BY CAST(store AS INTEGER), store;
            """,
            -1, &storeStmt, nil
        ) == SQLITE_OK {
            while sqlite3_step(storeStmt) == SQLITE_ROW {
                stores.append(ScheduleStore(
                    store: string(storeStmt, 0),
                    region: string(storeStmt, 1),
                    division: string(storeStmt, 2),
                    district: string(storeStmt, 3),
                    om: string(storeStmt, 4),
                    sales: optionalDouble(storeStmt, 5),
                    under: optionalDouble(storeStmt, 6),
                    over: optionalDouble(storeStmt, 7),
                    eff: optionalDouble(storeStmt, 8),
                    pch: optionalDouble(storeStmt, 9),
                    fourUnder: optionalDouble(storeStmt, 10),
                    fourOver: optionalDouble(storeStmt, 11),
                    star: optionalDouble(storeStmt, 12),
                    dayUnder: dayList(string(storeStmt, 13)),
                    dayOver: dayList(string(storeStmt, 14))
                ))
            }
        }
        return ScheduleCheckPack(
            publishedAt: publishedAt,
            week: week,
            filename: filename,
            summaryTitle: summaryTitle,
            workbookActionBanner: banner,
            markets: markets,
            stores: stores
        )
    }

    /// Replace schedule rows inside `current.sqlite` / a seat pack. Does not rewrite fact rows.
    static func writeSchedule(_ pack: ScheduleCheckPack, to url: URL) throws {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
            throw PulseSQLError.open
        }
        defer { sqlite3_close(db) }
        guard sqlite3_exec(db, scheduleDDL, nil, nil, nil) == SQLITE_OK else {
            throw PulseSQLError.schema
        }
        sqlite3_exec(db, "BEGIN IMMEDIATE;", nil, nil, nil)
        sqlite3_exec(db, "DELETE FROM schedule_store; DELETE FROM schedule_market; DELETE FROM schedule_pack;", nil, nil, nil)
        var meta: OpaquePointer?
        defer { sqlite3_finalize(meta) }
        guard sqlite3_prepare_v2(
            db,
            "INSERT INTO schedule_pack(id, published_at, week, filename, summary_title, workbook_action_banner) VALUES (1, ?, ?, ?, ?, ?);",
            -1, &meta, nil
        ) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw PulseSQLError.prepare
        }
        bind(meta, 1, pack.publishedAt)
        sqlite3_bind_int(meta, 2, Int32(pack.week))
        bind(meta, 3, pack.filename)
        bind(meta, 4, pack.summaryTitle)
        if let banner = pack.workbookActionBanner {
            sqlite3_bind_int(meta, 5, Int32(banner))
        } else {
            sqlite3_bind_null(meta, 5)
        }
        guard sqlite3_step(meta) == SQLITE_DONE else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw PulseSQLError.insert
        }

        var marketStmt: OpaquePointer?
        defer { sqlite3_finalize(marketStmt) }
        guard sqlite3_prepare_v2(
            db,
            "INSERT INTO schedule_market(label, under, over, eff) VALUES (?, ?, ?, ?);",
            -1, &marketStmt, nil
        ) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw PulseSQLError.prepare
        }
        for market in pack.markets {
            sqlite3_reset(marketStmt)
            sqlite3_clear_bindings(marketStmt)
            bind(marketStmt, 1, market.label)
            bindDouble(marketStmt, 2, market.under)
            bindDouble(marketStmt, 3, market.over)
            bindDouble(marketStmt, 4, market.eff)
            guard sqlite3_step(marketStmt) == SQLITE_DONE else {
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw PulseSQLError.insert
            }
        }

        var storeStmt: OpaquePointer?
        defer { sqlite3_finalize(storeStmt) }
        guard sqlite3_prepare_v2(
            db,
            """
            INSERT INTO schedule_store(
                store, region, division, district, om, sales, under, over, eff, pch, four_under, four_over, star, day_under_json, day_over_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            -1, &storeStmt, nil
        ) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw PulseSQLError.prepare
        }
        for store in pack.stores {
            sqlite3_reset(storeStmt)
            sqlite3_clear_bindings(storeStmt)
            bind(storeStmt, 1, store.store)
            bind(storeStmt, 2, store.region)
            bind(storeStmt, 3, store.division)
            bind(storeStmt, 4, store.district)
            bind(storeStmt, 5, store.om)
            bindDouble(storeStmt, 6, store.sales)
            bindDouble(storeStmt, 7, store.under)
            bindDouble(storeStmt, 8, store.over)
            bindDouble(storeStmt, 9, store.eff)
            bindDouble(storeStmt, 10, store.pch)
            bindDouble(storeStmt, 11, store.fourUnder)
            bindDouble(storeStmt, 12, store.fourOver)
            bindDouble(storeStmt, 13, store.star)
            bind(storeStmt, 14, jsonDays(store.dayUnder))
            bind(storeStmt, 15, jsonDays(store.dayOver))
            guard sqlite3_step(storeStmt) == SQLITE_DONE else {
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw PulseSQLError.insert
            }
        }
        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
    }

    static func readChrome(from url: URL) -> PulseDashChrome? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            return nil
        }
        defer { sqlite3_close(db) }
        return readChrome(db: db)
    }

    private static func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(stmt, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private static func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: Int) {
        sqlite3_bind_int(stmt, index, Int32(value))
    }

    private static func bindDouble(_ stmt: OpaquePointer?, _ index: Int32, _ value: Double?) {
        if let value {
            sqlite3_bind_double(stmt, index, value)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private static func optionalDouble(_ stmt: OpaquePointer?, _ index: Int32) -> Double? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(stmt, index)
    }

    private static func jsonDays(_ days: [Double?]) -> String {
        let values: [Any] = days.map { value in
            if let value { return value }
            return NSNull()
        }
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: []),
              let text = String(data: data, encoding: .utf8)
        else { return "[null,null,null,null,null,null,null]" }
        return text
    }

    private static func dayList(_ raw: String) -> [Double?] {
        guard let data = raw.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any]
        else { return Array(repeating: nil, count: 7) }
        let days = array.map { item -> Double? in
            if item is NSNull { return nil }
            if let number = item as? Double { return number }
            if let number = item as? NSNumber { return number.doubleValue }
            return nil
        }
        if days.count == 7 { return days }
        var padded = days
        while padded.count < 7 { padded.append(nil) }
        return Array(padded.prefix(7))
    }

    private static func string(_ stmt: OpaquePointer?, _ index: Int32) -> String {
        guard let raw = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: raw)
    }

    private static func optional(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        return string(stmt, index)
    }

    private static func encodeMap(_ map: [String: Double]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: map, options: []),
              let text = String(data: data, encoding: .utf8)
        else { return "{}" }
        return text
    }

    private static func encodeText(_ map: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: map, options: []),
              let text = String(data: data, encoding: .utf8)
        else { return "{}" }
        return text
    }

    private static func decodeMap(_ raw: String) -> [String: Double] {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        var out: [String: Double] = [:]
        for (key, value) in object {
            if let number = value as? Double {
                out[key] = number
            } else if let number = value as? NSNumber {
                out[key] = number.doubleValue
            }
        }
        return out
    }

    private static func decodeText(_ raw: String) -> [String: String] {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [:] }
        return object
    }

    private static func encodeUploads(_ uploads: [UploadRecord]) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(uploads),
              let text = String(data: data, encoding: .utf8)
        else { return "[]" }
        return text
    }

    private static func decodeUploads(_ raw: String) -> [UploadRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = raw.data(using: .utf8),
              let uploads = try? decoder.decode([UploadRecord].self, from: data)
        else { return [] }
        return uploads
    }
}

enum PulseSQLError: LocalizedError {
    case open, schema, prepare, insert

    var errorDescription: String? {
        switch self {
        case .open: return "Could not open the Heartbeat database pack."
        case .schema: return "Could not write a new Heartbeat database pack."
        case .prepare: return "Could not write the Heartbeat database pack."
        case .insert: return "Could not save scorecard rows into the database pack."
        }
    }
}
