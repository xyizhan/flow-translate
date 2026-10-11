import Foundation

enum BuildIdentity {
    static let appURL = Bundle.main.bundleURL
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }
    static var buildID: String {
        Bundle.main.object(forInfoDictionaryKey: "FlowTranslateBuildID") as? String ?? "—"
    }
    static var date: Date? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "FlowTranslateBuildDate") as? String else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}
