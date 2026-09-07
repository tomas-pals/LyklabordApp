import Foundation

/// Recency-ordered email addresses the user has typed in email fields.
///
/// Separate from `PersonalModel` — email localparts are not vocabulary, and
/// the learning privacy gate forbids mixing field-kind email text into the
/// word log. This store is App Group local, never synced, and never written
/// while incognito.
public struct EmailAddressStore: Codable, Equatable, Sendable {
    public static let fileName = "email-addresses.json"
    public static let maxCount = 100

    /// Newest first, original casing preserved.
    public private(set) var addresses: [String]

    public init(addresses: [String] = []) {
        self.addresses = addresses
    }

    public static func isEmail(_ raw: String) -> Bool {
        let email = normalize(raw)
        let parts = email.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let local = parts[0]
        let domain = parts[1]
        guard !local.isEmpty, !local.hasPrefix("."), !local.hasSuffix(".") else { return false }
        guard domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix(".") else {
            return false
        }
        return domain.split(separator: ".").allSatisfy { !$0.isEmpty }
    }

    public mutating func record(_ raw: String) {
        guard Self.isEmail(raw) else { return }
        let email = Self.normalize(raw)
        let key = email.lowercased()
        addresses.removeAll { $0.lowercased() == key }
        addresses.insert(email, at: 0)
        if addresses.count > Self.maxCount {
            addresses.removeLast(addresses.count - Self.maxCount)
        }
    }

    /// Pull complete emails out of a document window (committed tokens).
    public mutating func ingest(from text: String) {
        for token in text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }) {
            record(String(token).trimmingCharacters(in: .punctuationCharacters))
        }
    }

    public func suggestions(prefix: String, limit: Int = 4) -> [String] {
        let needle = prefix.lowercased()
        let matches: [String]
        if needle.isEmpty {
            matches = addresses
        } else {
            matches = addresses.filter { $0.lowercased().hasPrefix(needle) }
        }
        return Array(matches.prefix(limit))
    }

    public static func load(from url: URL) -> EmailAddressStore {
        guard let data = try? Data(contentsOf: url),
            let store = try? JSONDecoder().decode(EmailAddressStore.self, from: data)
        else { return EmailAddressStore() }
        return store
    }

    public func write(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }

    private static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
