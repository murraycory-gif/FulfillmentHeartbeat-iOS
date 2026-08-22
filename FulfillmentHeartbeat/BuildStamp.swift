import Foundation

enum BuildStamp {
    static let id = "HB-0821.33"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static var number: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "4"
    }

    static var label: String {
        "\(id)  \(version) (\(number))"
    }
}
