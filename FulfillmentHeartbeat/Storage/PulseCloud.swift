import Foundation

enum PulseCloud {
    static let projectURL = URL(string: "https://pcnjujfmlsklhrosxzlt.supabase.co")!
    static let publishableKey = "sb_publishable_T3Pzm01sMXCv2rQaCeP_Kg_4ao2M5zd"
    static let bucket = "heartbeat-packs"
    static let object = "current.sqlite"
    static let seatManifestObject = PulseSeatPack.manifestObject
    static let cardsObject = "pulse-cards.json"
    static let factsObject = PulseFacts.object
    static let workbookNames = [
        "Heartbeat Daily Report.xlsx",
        "current.xlsx",
        "master.xlsx",
    ]

    static var packURL: URL {
        projectURL.appendingPathComponent("storage/v1/object/\(bucket)/\(object)")
    }

    static var publicPackURL: URL {
        projectURL.appendingPathComponent("storage/v1/object/public/\(bucket)/\(object)")
    }

    struct ObjectStat {
        var size: Int
        var updated: String
    }

    static func snapshot() async -> [String: ObjectStat] {
        var map: [String: ObjectStat] = [:]
        for row in await listObjects() {
            guard let name = row["name"] as? String else { continue }
            let meta = row["metadata"] as? [String: Any]
            let size = objectByteCount(from: meta)
            let updated = (row["updated_at"] as? String) ?? (row["created_at"] as? String) ?? ""
            map[name] = ObjectStat(size: size, updated: updated)
        }
        return map
    }

    static func objectSize(_ name: String) async -> Int {
        let info = await objectInfo(name)
        return info.size
    }

    /// Targeted list for one object. Do not use the cached 200-row root listing
    /// for pack freshness — nested seats are not in that snapshot.
    static func objectInfo(_ name: String) async -> (size: Int, updated: String) {
        if let hit = await listedObject(named: name, useCache: false) {
            return (hit.size, hit.updated)
        }
        return (0, "")
    }

    /// Authenticated first — public / bare object can 403 or return a stub.
    static func objectDownloadURLs(_ name: String) -> [URL] {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return [
            URL(string: "https://pcnjujfmlsklhrosxzlt.supabase.co/storage/v1/object/authenticated/\(bucket)/\(encoded)"),
            URL(string: "https://pcnjujfmlsklhrosxzlt.supabase.co/storage/v1/object/public/\(bucket)/\(encoded)"),
            URL(string: "https://pcnjujfmlsklhrosxzlt.supabase.co/storage/v1/object/\(bucket)/\(encoded)"),
        ].compactMap { $0 }
    }

    private static var listedAt: Date?
    private static var listedRows: [[String: Any]] = []

    static func invalidateObjectList() {
        listedAt = nil
        listedRows = []
    }

    /// Storage metadata size is often NSNumber / Double, not Int.
    static func objectByteCount(from metadata: [String: Any]?) -> Int {
        intValue(metadata?["size"]) ?? intValue(metadata?["contentLength"]) ?? 0
    }

    static func intValue(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        if let value = raw as? Double { return Int(value) }
        if let value = raw as? String { return Int(value) }
        return nil
    }

    private static func listedObject(named name: String, useCache: Bool) async -> ObjectStat? {
        let prefix: String
        if let slash = name.lastIndex(of: "/") {
            prefix = String(name[..<slash]) + "/"
        } else {
            prefix = ""
        }
        let leaf = name.split(separator: "/").map(String.init).last ?? name
        let rows = await listObjects(prefix: prefix, useCache: useCache && prefix.isEmpty)
        for row in rows {
            guard let listed = row["name"] as? String else { continue }
            if listed != leaf, listed != name { continue }
            let meta = row["metadata"] as? [String: Any]
            let size = objectByteCount(from: meta)
            let updated = (row["updated_at"] as? String) ?? (row["created_at"] as? String) ?? ""
            return ObjectStat(size: size, updated: updated)
        }
        return nil
    }

    private static func listObjects(prefix: String = "", useCache: Bool = true) async -> [[String: Any]] {
        let cacheRoot = useCache && prefix.isEmpty
        if cacheRoot, let listedAt, Date().timeIntervalSince(listedAt) < 20, !listedRows.isEmpty {
            return listedRows
        }
        var request = URLRequest(url: projectURL.appendingPathComponent("storage/v1/object/list/\(bucket)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["prefix": prefix, "limit": 200])
        request.timeoutInterval = 20
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return cacheRoot ? listedRows : [] }
        if cacheRoot {
            listedAt = Date()
            listedRows = rows
        }
        return rows
    }

    static func downloadNamed(_ name: String) async throws -> Data {
        let urls = objectDownloadURLs(name)
        var last: Error = PulseCloudError.missing
        for url in urls {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 180
            request.cachePolicy = .reloadIgnoringLocalCacheData
            applyAuth(&request)
            do {
                let (temp, response) = try await URLSession.shared.download(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    last = PulseCloudError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
                    continue
                }
                let data = try Data(contentsOf: temp, options: [.mappedIfSafe])
                guard data.count > 1_000 else {
                    last = PulseCloudError.missing
                    continue
                }
                return data
            } catch {
                last = error
            }
        }
        throw last
    }

    /// Seat object path, e.g. `packs/seat/district/03/current.sqlite`.
    static func downloadObject(_ name: String, to dest: URL, timeout: TimeInterval = 180) async throws -> Int {
        let urls = objectDownloadURLs(name)
        var last: Error = PulseCloudError.missing
        for url in urls {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = timeout
            request.cachePolicy = .reloadIgnoringLocalCacheData
            applyAuth(&request)
            do {
                let (temp, response) = try await URLSession.shared.download(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    last = PulseCloudError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
                    continue
                }
                let size = (try FileManager.default.attributesOfItem(atPath: temp.path)[.size] as? NSNumber)?.intValue ?? 0
                guard size > 1_000 else {
                    last = PulseCloudError.missing
                    continue
                }
                let folder = dest.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.moveItem(at: temp, to: dest)
                return size
            } catch {
                last = error
            }
        }
        throw last
    }

    static func downloadPack() async throws -> Data {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("heartbeat-pack-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: temp) }
        let size = try await downloadPack(to: temp)
        guard size > 50_000 else { throw PulseCloudError.missing }
        return try Data(contentsOf: temp, options: [.mappedIfSafe])
    }

    /// Stream the pack to a staging file. Never pass the live `heartbeat.sqlite`
    /// while it may still be memory-mapped.
    static func downloadPack(to dest: URL, timeout: TimeInterval = 180) async throws -> Int {
        var last: Error = PulseCloudError.missing
        for url in objectDownloadURLs(object) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = timeout
            request.cachePolicy = .reloadIgnoringLocalCacheData
            applyAuth(&request)
            do {
                let (temp, response) = try await URLSession.shared.download(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    last = PulseCloudError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
                    continue
                }
                let size = (try FileManager.default.attributesOfItem(atPath: temp.path)[.size] as? NSNumber)?.intValue ?? 0
                guard size > 50_000 else {
                    last = PulseCloudError.missing
                    continue
                }
                let folder = dest.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let staged = folder.appendingPathComponent("heartbeat-incoming.sqlite")
                if FileManager.default.fileExists(atPath: staged.path) {
                    try FileManager.default.removeItem(at: staged)
                }
                try FileManager.default.moveItem(at: temp, to: staged)
                if FileManager.default.fileExists(atPath: dest.path) {
                    _ = try FileManager.default.replaceItemAt(dest, withItemAt: staged)
                } else {
                    try FileManager.default.moveItem(at: staged, to: dest)
                }
                return size
            } catch {
                last = error
            }
        }
        throw last
    }

    static func uploadPack(_ data: Data) async throws {
        try await uploadObject(object, data: data, contentType: "application/octet-stream")
    }

    static func uploadCards(_ data: Data) async throws {
        try await uploadObject(cardsObject, data: data, contentType: "application/json")
    }

    static func uploadFacts(_ data: Data) async throws {
        try await uploadObject(factsObject, data: data, contentType: "application/json")
    }

    /// Upload `packs/manifest.json` plus every company / district / store seat sqlite.
    static func publishSeatPacks(root: URL, manifest: PulseSeatPack.Manifest) async throws {
        let manifestURL = root.appendingPathComponent(PulseSeatPack.manifestObject)
        let manifestData: Data
        if let disk = try? Data(contentsOf: manifestURL), !disk.isEmpty {
            manifestData = disk
        } else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            manifestData = try encoder.encode(manifest)
        }
        try await uploadObject(PulseSeatPack.manifestObject, data: manifestData, contentType: "application/json")
        for entry in manifest.allEntries {
            let file = root.appendingPathComponent(entry.path)
            guard PulseSeatPack.isUsable(at: file) else { throw PulseCloudError.upload }
            let data = try Data(contentsOf: file, options: [.mappedIfSafe])
            try await uploadObject(entry.path, data: data, contentType: "application/octet-stream")
        }
        invalidateObjectList()
    }

    static func downloadFacts() async throws -> Data {
        try await downloadNamed(factsObject)
    }

    static func downloadCards() async throws -> Data {
        try await downloadNamed(cardsObject)
    }

    private static func uploadObject(_ name: String, data: Data, contentType: String) async throws {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let url = projectURL.appendingPathComponent("storage/v1/object/\(bucket)/\(encoded)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        applyAuth(&request)
        request.httpBody = data
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            var retry = URLRequest(url: url)
            retry.httpMethod = "PUT"
            retry.setValue(contentType, forHTTPHeaderField: "Content-Type")
            retry.setValue("true", forHTTPHeaderField: "x-upsert")
            applyAuth(&retry)
            retry.httpBody = data
            let (_, putResponse) = try await URLSession.shared.data(for: retry)
            guard let putHTTP = putResponse as? HTTPURLResponse, (200...299).contains(putHTTP.statusCode) else {
                throw PulseCloudError.upload
            }
            return
        }
    }

    private static func applyAuth(_ request: inout URLRequest) {
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
    }
}

enum PulseCloudError: LocalizedError {
    case network, missing, upload, http(Int)

    var errorDescription: String? {
        switch self {
        case .network: return "Could not reach the Heartbeat cloud project."
        case .missing: return "No cloud pack is published yet."
        case .upload: return "Could not publish the Heartbeat pack."
        case .http(let code): return "Cloud pack request failed (\(code))."
        }
    }
}
