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
    }

    static func write(rows: [MetricRow], uploads: [UploadRecord], seeded: Bool, to url: URL) throws {
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
            bind(insert, 1, row.id.uuidString)
            bind(insert, 2, row.section.rawValue)
            bind(insert, 3, row.storeNumber)
            bind(insert, 4, row.division)
            bind(insert, 5, row.operationsOM)
            bind(insert, 6, row.storeName)
            bind(insert, 7, row.recordedOn)
            bind(insert, 8, encodeMap(row.payload))
            bind(insert, 9, encodeText(row.textPayload))
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
        bind(meta, 3, ISO8601DateFormatter().string(from: Date()))
        bind(meta, 4, encodeUploads(uploads))
        bind(meta, 5, encodeText(counts.mapValues { String($0) }))
        guard sqlite3_step(meta) == SQLITE_DONE else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw PulseSQLError.insert
        }
        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: temp, to: url)
    }

    static func read(from url: URL, skipping skip: Set<MetricSection> = [], only: Set<MetricSection> = []) throws -> Pack {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            throw PulseSQLError.open
        }
        defer { sqlite3_close(db) }

        #if canImport(UIKit)
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
            let idRaw = string(stmt, 0)
            let sectionRaw = string(stmt, 1)
            guard let section = MetricSection(rawValue: sectionRaw) else { continue }
            let row = MetricRow(
                id: UUID(uuidString: idRaw) ?? UUID(),
                section: section,
                division: string(stmt, 3),
                operationsOM: string(stmt, 4),
                storeNumber: string(stmt, 2),
                storeName: optional(stmt, 5),
                recordedOn: optional(stmt, 6),
                payload: decodeMap(optional(stmt, 7) ?? "{}"),
                textPayload: decodeText(optional(stmt, 8) ?? "{}")
            )
            rows.append(row)
            counts[section.rawValue, default: 0] += 1
        }
        return Pack(rows: rows, uploads: uploads, seeded: seeded, counts: counts, writtenAt: writtenAt)
    }

    static func exists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
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
        text_json TEXT
    );
    CREATE INDEX facts_section_store ON facts(section, store_number);
    CREATE INDEX facts_section_div ON facts(section, division);
    """

    private static let insertSQL = """
    INSERT INTO facts(id, section, store_number, division, operations_om, store_name, recorded_on, payload_json, text_json)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    private static func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(stmt, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, index)
        }
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
