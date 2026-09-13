import Foundation

/// Per-language list of suggestion-bar words the user hid via long-press.
///
/// Distinct from `PersonalModel` tombstones: hiding a suggestion is a typing
/// preference ("never offer this word again in this language"), not a
/// dictionary deletion. It is always on — not gated behind Lyklaborð+ —
/// because it applies to base-lexicon suggestions as well as learned ones.
///
/// Persisted in the App Group `UserDefaults` suite so the containing app's
/// settings screen and the keyboard extension share one list. Matching is
/// case-insensitive; the surface form from the bar is kept for display.
public struct HiddenSuggestionsStore {

    /// Key prefix. Language raw value (`is` / `en`) is appended.
    public static let defaultsKeyPrefix =
        "com.supermassiveapps.lyklabord.settings.hiddenSuggestions."

    public static func defaultsKey(for language: LearningLanguage) -> String {
        defaultsKeyPrefix + language.rawValue
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public init?(appGroupId: String) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return nil }
        self.init(defaults: defaults)
    }

    /// Display-ordered surface forms hidden for `language`.
    public func words(for language: LearningLanguage) -> [String] {
        defaults.stringArray(forKey: Self.defaultsKey(for: language)) ?? []
    }

    /// Lowercased set for engine matching.
    public func hiddenSet(for language: LearningLanguage) -> Set<String> {
        Set(words(for: language).map { $0.lowercased() })
    }

    /// Hide `word` for `language`. No-op on empty/whitespace. Case-insensitive
    /// de-dupe keeps the first surface form the user hid.
    public func hide(_ word: String, language: LearningLanguage) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lower = trimmed.lowercased()
        var list = words(for: language)
        guard !list.contains(where: { $0.lowercased() == lower }) else { return }
        list.append(trimmed)
        write(list, language: language)
    }

    /// Restore a previously hidden word (case-insensitive match).
    public func unhide(_ word: String, language: LearningLanguage) {
        let lower = word.lowercased()
        let list = words(for: language).filter { $0.lowercased() != lower }
        write(list, language: language)
    }

    public func isHidden(_ word: String, language: LearningLanguage) -> Bool {
        hiddenSet(for: language).contains(word.lowercased())
    }

    /// Wipe both languages. Called from "delete all my data".
    public func clearAll() {
        for language in LearningLanguage.allCases {
            defaults.removeObject(forKey: Self.defaultsKey(for: language))
        }
    }

    private func write(_ list: [String], language: LearningLanguage) {
        let sorted = list.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        defaults.set(sorted, forKey: Self.defaultsKey(for: language))
    }
}
