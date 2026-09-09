import Foundation

enum PulseCloud {
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
            var size = 0
            if let meta = row["metadata"] as? [String: Any] {
                if let value = meta["size"] as? Int { size = value }
                else if let value = meta["contentLength"] as? Int { size = value }
            }
            let updated = (row["updated_at"] as? String) ?? (row["created_at"] as? String) ?? ""
            map[name] = ObjectStat(size: size, updated: updated)
        }
        return map
    }

    static func objectSize(_ name: String) async -> Int {
        let info = await objectInfo(name)
        return info.size
    }

    static func objectInfo(_ name: String) async -> (size: Int, updated: String) {
        let map = await snapshot()
        let stat = map[name]
        return (stat?.size ?? 0, stat?.updated ?? "")
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
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let urls = [
            URL(string: "https://pcnjujfmlsklhrosxzlt.supabase.co/storage/v1/object/public/\(bucket)/\(encoded)"),
            URL(string: "https://pcnjujfmlsklhrosxzlt.supabase.co/storage/v1/object/\(bucket)/\(encoded)"),
        ].compactMap { $0 }
        var last: Error = PulseCloudError.missing
        for url in urls {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 180
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
        for url in [packURL, publicPackURL] {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 180
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
