import Foundation

enum PulseCloud {
    static let projectURL = URL(string: "https://pcnjujfmlsklhrosxzlt.supabase.co")!
    static let publishableKey = "sb_publishable_T3Pzm01sMXCv2rQaCeP_Kg_4ao2M5zd"
    static let bucket = "heartbeat-packs"
    static let object = "current.sqlite"
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

    static func objectSize(_ name: String) async -> Int {
        var request = URLRequest(url: projectURL.appendingPathComponent("storage/v1/object/list/\(bucket)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["prefix": "", "limit": 50])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return 0 }
        for row in rows {
            guard let fileName = row["name"] as? String, fileName == name else { continue }
            if let meta = row["metadata"] as? [String: Any] {
                if let size = meta["size"] as? Int { return size }
                if let size = meta["contentLength"] as? Int { return size }
            }
        }
        return 0
    }

    static func downloadNamed(_ name: String) async throws -> Data {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let url = projectURL.appendingPathComponent("storage/v1/object/\(bucket)/\(encoded)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuth(&request)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count > 1_000 else {
            throw PulseCloudError.missing
        }
        return data
    }

    static func downloadPack() async throws -> Data {
        var request = URLRequest(url: packURL)
        request.httpMethod = "GET"
        applyAuth(&request)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PulseCloudError.network }
        if http.statusCode == 200, !data.isEmpty { return data }
        if http.statusCode == 400 || http.statusCode == 404 {
            var fallback = URLRequest(url: publicPackURL)
            fallback.httpMethod = "GET"
            applyAuth(&fallback)
            let (alt, altResponse) = try await URLSession.shared.data(for: fallback)
            guard let altHTTP = altResponse as? HTTPURLResponse, altHTTP.statusCode == 200, !alt.isEmpty else {
                throw PulseCloudError.missing
            }
            return alt
        }
        throw PulseCloudError.http(http.statusCode)
    }

    static func uploadPack(_ data: Data) async throws {
        var request = URLRequest(url: packURL)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        applyAuth(&request)
        request.httpBody = data
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            var retry = URLRequest(url: packURL)
            retry.httpMethod = "PUT"
            retry.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
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
