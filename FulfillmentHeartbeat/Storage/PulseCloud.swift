import Foundation

enum PulseCloud {
    /// Public pack host (Cloudflare R2). Swap `HBPackHost` in Info.plist — or
    /// this fallback — to a custom domain later. `r2.dev` is rate-limited.
    static let defaultPackHost = "https://pub-eafb309f53464d98902d12ac107f0f1e.r2.dev"

    static var packHostBaseURL: URL {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "HBPackHost") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (raw?.isEmpty == false) ? raw! : defaultPackHost
        return URL(string: value) ?? URL(string: defaultPackHost)!
    }

    /// Workbook source still lives here. Tester pack downloads do not.
    static let projectURL = URL(string: "https://pcnjujfmlsklhrosxzlt.supabase.co")!
    static let publishableKey = "sb_publishable_T3Pzm01sMXCv2rQaCeP_Kg_4ao2M5zd"
    static let bucket = "heartbeat-packs"
    static let object = "current.sqlite"
    static let cardsObject = "pulse-cards.json"
    static let factsObject = PulseFacts.object
    static let workbookNames = [
        "Heartbeat Daily Report.xlsx",
        "current.xlsx",
        "master.xlsx",
    ]

    static var packURL: URL { packObjectURL(object) }

    static var publicPackURL: URL { packObjectURL(object) }

    static func packObjectURL(_ name: String) -> URL {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let base = packHostBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/\(encoded)") ?? packHostBaseURL.appendingPathComponent(encoded)
    }

    static func isWorkbookName(_ name: String) -> Bool {
        workbookNames.contains(name)
    }

    /// Packs (`current.sqlite`, seats, cards, facts) come from R2.
    /// Workbooks stay on Supabase Storage.
    static func objectDownloadURLs(_ name: String) -> [URL] {
        if isWorkbookName(name) {
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            return [
                URL(string: "https://pcnjujfmlsklhrosxzlt.supabase.co/storage/v1/object/authenticated/\(bucket)/\(encoded)"),
                URL(string: "https://pcnjujfmlsklhrosxzlt.supabase.co/storage/v1/object/public/\(bucket)/\(encoded)"),
                URL(string: "https://pcnjujfmlsklhrosxzlt.supabase.co/storage/v1/object/\(bucket)/\(encoded)"),
            ].compactMap { $0 }
        }
        return [packObjectURL(name)]
    }

    struct ObjectStat {
        var size: Int
        var updated: String
    }

    static func snapshot() async -> [String: ObjectStat] {
        var map = await listedWorkbookStats()
        for name in [object, cardsObject, factsObject] {
            if let stat = await headPackObject(name) {
                map[name] = stat
            } else {
                map.removeValue(forKey: name)
            }
        }
        return map
    }

    static func objectSize(_ name: String) async -> Int {
        let info = await objectInfo(name)
        return info.size
    }

    /// Pack freshness is an R2 HEAD. Workbooks still list from Supabase Storage.
    static func objectInfo(_ name: String) async -> (size: Int, updated: String) {
        if isWorkbookName(name) {
            let stat = await listedWorkbookStats()[name]
            return (stat?.size ?? 0, stat?.updated ?? "")
        }
        if let stat = await headPackObject(name) {
            return (stat.size, stat.updated)
        }
        return (0, "")
    }

    private static func listedWorkbookStats() async -> [String: ObjectStat] {
        var map: [String: ObjectStat] = [:]
        for row in await listObjects() {
            guard let name = row["name"] as? String else { continue }
            var size = 0
            if let meta = row["metadata"] as? [String: Any] {
                if let value = meta["size"] as? Int { size = value }
                else if let value = meta["contentLength"] as? Int { size = value }
                else if let value = meta["size"] as? NSNumber { size = value.intValue }
                else if let value = meta["contentLength"] as? NSNumber { size = value.intValue }
            }
            let updated = (row["updated_at"] as? String) ?? (row["created_at"] as? String) ?? ""
            map[name] = ObjectStat(size: size, updated: updated)
        }
        return map
    }

    private static func headPackObject(_ name: String) async -> ObjectStat? {
        let url = packObjectURL(name)
        var head = URLRequest(url: url)
        head.httpMethod = "HEAD"
        head.timeoutInterval = 20
        head.cachePolicy = .reloadIgnoringLocalCacheData
        if let http = await httpResponse(for: head), http.statusCode == 200 {
            let size = headerInt(http, "Content-Length")
            let updated = http.value(forHTTPHeaderField: "Last-Modified") ?? ""
            if size > 0 || !updated.isEmpty {
                return ObjectStat(size: size, updated: updated)
            }
        }
        var ranged = URLRequest(url: url)
        ranged.httpMethod = "GET"
        ranged.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        ranged.timeoutInterval = 20
        ranged.cachePolicy = .reloadIgnoringLocalCacheData
        if let http = await httpResponse(for: ranged), (200...206).contains(http.statusCode) {
            let size = contentRangeTotal(http.value(forHTTPHeaderField: "Content-Range"))
                ?? headerInt(http, "Content-Length")
            let updated = http.value(forHTTPHeaderField: "Last-Modified") ?? ""
            if size > 0 || !updated.isEmpty {
                return ObjectStat(size: size, updated: updated)
            }
        }
        return nil
    }

    private static func httpResponse(for request: URLRequest) async -> HTTPURLResponse? {
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return nil }
        return response as? HTTPURLResponse
    }

    private static func headerInt(_ http: HTTPURLResponse, _ name: String) -> Int {
        Int(http.value(forHTTPHeaderField: name) ?? "") ?? 0
    }

    private static func contentRangeTotal(_ raw: String?) -> Int? {
        guard let raw, let slash = raw.lastIndex(of: "/") else { return nil }
        return Int(raw[raw.index(after: slash)...])
    }

    private static var listedAt: Date?
    private static var listedRows: [[String: Any]] = []

    private static func listObjects() async -> [[String: Any]] {
        if let listedAt, Date().timeIntervalSince(listedAt) < 20, !listedRows.isEmpty {
            return listedRows
        }
        var request = URLRequest(url: projectURL.appendingPathComponent("storage/v1/object/list/\(bucket)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["prefix": "", "limit": 50])
        request.timeoutInterval = 20
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return listedRows }
        listedAt = Date()
        listedRows = rows
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
            if isWorkbookName(name) {
                applyAuth(&request)
            }
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

    static func downloadPack() async throws -> Data {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("heartbeat-pack-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: temp) }
        let size = try await downloadPack(to: temp)
        guard size > 50_000 else { throw PulseCloudError.missing }
        return try Data(contentsOf: temp, options: [.mappedIfSafe])
    }

    /// Stream the pack to disk. Do not hold the file in RAM (iPhone 13 jetsam).
    static func downloadPack(to dest: URL) async throws -> Int {
        var last: Error = PulseCloudError.missing
        for url in objectDownloadURLs(object) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 180
            request.cachePolicy = .reloadIgnoringLocalCacheData
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

    static func downloadFacts() async throws -> Data {
        try await downloadNamed(factsObject)
    }

    static func downloadCards() async throws -> Data {
        try await downloadNamed(cardsObject)
    }

    /// Kitchen leftover. Tester downloads read R2. R2 keys stay out of the app.
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
