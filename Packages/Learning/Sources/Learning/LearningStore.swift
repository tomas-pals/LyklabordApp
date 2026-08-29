import Foundation

/// The language a personal-learning store belongs to.
///
/// Icelandic and English vocabulary are learned into SEPARATE stores — their
/// own model file and their own event log — so nothing the user teaches the
/// keyboard in one language can surface as a suggestion in the other. The
/// engine enforces the same split on the base lexicons
/// (`EngineConfig.pinnedLanguage`); this is the personal half of it.
///
/// Splitting the files rather than tagging rows inside one file is
/// deliberate. The stores decay, evict and compact independently (a heavy
/// Icelandic month must not decay away English vocabulary), the dictionary
/// editor shows exactly one of them at a time, and the extension only ever
/// loads the one it needs.
public enum LearningLanguage: String, Codable, Sendable, CaseIterable, Identifiable {
    case icelandic = "is"
    case english = "en"

    public var id: String { rawValue }

    /// Per-language file names inside the App Group container.
    public var personalModelFileName: String { "personal-model-\(rawValue).json" }
    public var eventLogFileName: String { "learning-events-\(rawValue).log" }

    /// The `LanguageHint` a store of this language records on commits.
    public var hint: LanguageHint {
        switch self {
        case .icelandic: .icelandic
        case .english: .english
        }
    }

    /// Which store an unsplit legacy event belongs in. `unknown` attributions
    /// go to Icelandic: it is the keyboard's primary language and the lane
    /// model only ever emitted `unknown` when the evidence was too thin to
    /// call, which for this user base means Icelandic far more often than not.
    public static func owning(_ hint: LanguageHint) -> LearningLanguage {
        switch hint {
        case .icelandic, .unknown: .icelandic
        case .english: .english
        }
    }
}

/// One-time migration of the pre-split personal store.
///
/// Before language separation there was a single `personal-model.json` and a
/// single `learning-events.log`. Both are split here — the model by the
/// per-word language attribution that was already being recorded
/// (`WordStats.icelandicCount` / `englishCount`), the log by each event's
/// `LanguageHint` — and the legacy files are then removed.
///
/// Unconsumed log events are applied straight into the split models rather
/// than re-appended to the new logs, because `EventLog.append` stamps events
/// with TODAY's day bucket and the distinct-day learning threshold depends on
/// the original ones. Applying them here is exactly what the compactor would
/// have done, with the days intact.
///
/// Idempotent, and safe to call on every launch: with no legacy file present
/// it does nothing.
public enum LearningStoreMigration {

    public static let legacyPersonalModelFileName = "personal-model.json"
    public static let legacyEventLogFileName = "learning-events.log"

    public struct Summary: Equatable, Sendable {
        public var migrated: Bool
        /// Words routed to each store.
        public var wordCounts: [LearningLanguage: Int]
        /// Unconsumed legacy events applied to each store.
        public var eventCounts: [LearningLanguage: Int]

        public init(
            migrated: Bool = false,
            wordCounts: [LearningLanguage: Int] = [:],
            eventCounts: [LearningLanguage: Int] = [:]
        ) {
            self.migrated = migrated
            self.wordCounts = wordCounts
            self.eventCounts = eventCounts
        }
    }

    /// `run`, wrapped in one coordinated write on the legacy event log.
    ///
    /// Both the app and the keyboard extension call this on startup, and on
    /// a fresh install after an update they can genuinely race. Coordinating
    /// on the legacy log — the same file `EventLog` appends to and the
    /// compactor truncates — serializes them against each other and against
    /// an in-flight flush, so the loser of the race finds the legacy files
    /// already gone and returns an unmigrated `Summary`.
    @discardableResult
    public static func runCoordinated(
        in container: URL,
        configuration: PersonalModel.Configuration = PersonalModel.Configuration()
    ) throws -> Summary {
        try CoordinatedFileAccess.coordinateWrite(
            at: container.appendingPathComponent(legacyEventLogFileName)
        ) { _ in
            try run(in: container, configuration: configuration)
        }
    }

    /// Split whatever legacy files exist in `container`. Never overwrites an
    /// already-migrated store: if any per-language model is present the
    /// legacy files are just discarded, which is the right call for a re-run
    /// after a partial migration.
    @discardableResult
    public static func run(
        in container: URL,
        configuration: PersonalModel.Configuration = PersonalModel.Configuration()
    ) throws -> Summary {
        let files = FileManager.default
        let legacyModelURL = container.appendingPathComponent(legacyPersonalModelFileName)
        let legacyLogURL = container.appendingPathComponent(legacyEventLogFileName)
        defer {
            try? files.removeItem(at: legacyModelURL)
            try? files.removeItem(at: legacyLogURL)
        }

        let hasLegacy =
            files.fileExists(atPath: legacyModelURL.path)
            || files.fileExists(atPath: legacyLogURL.path)
        let alreadySplit = LearningLanguage.allCases.contains {
            files.fileExists(atPath: container.appendingPathComponent($0.personalModelFileName).path)
        }
        guard hasLegacy, !alreadySplit else { return Summary() }

        let legacy =
            files.fileExists(atPath: legacyModelURL.path)
            ? try PersonalModel(contentsOf: legacyModelURL, configuration: configuration)
            : PersonalModel(configuration: configuration)
        let split = legacy.split(configuration: configuration)

        var summary = Summary(migrated: true)
        if files.fileExists(atPath: legacyLogURL.path) {
            let unconsumed = try EventLog(url: legacyLogURL)
                .read(after: legacy.consumedLogMarker)
                .events
            for logged in unconsumed {
                let language = LearningLanguage.owning(logged.hint)
                split[language]?.applyMigrated(logged)
                summary.eventCounts[language, default: 0] += 1
            }
        }

        for (language, model) in split {
            // The new per-language logs start empty, so no consumed frontier
            // carries over — a stale marker would point at a generation UUID
            // that no longer exists anyway.
            model.clearConsumedLogMarker()
            try model.save(to: container.appendingPathComponent(language.personalModelFileName))
            // Every word routed here, not just the ones already over the
            // distinct-day learning threshold: this counts what the split
            // MOVED, and a word one day short of being learned still had to
            // land in the right store.
            summary.wordCounts[language] = model.words.count
        }
        return summary
    }
}

extension LoggedEvent {
    /// The language this event should be filed under. Only `wordCommitted`
    /// carries an explicit hint; the rest (taps, accepts, reverts, touch
    /// samples) have none, so they follow the same `unknown` rule.
    var hint: LanguageHint {
        if case .wordCommitted(_, _, let hint) = event { return hint }
        return .unknown
    }
}

extension PersonalModel {
    /// Partition this model into one store per language, using the
    /// attribution already recorded on every word. A word whose commits are
    /// tied (or entirely `unknown`) goes to Icelandic — see
    /// `LearningLanguage.owning`.
    ///
    /// Tombstones and user-added words are copied to BOTH stores: a deletion
    /// means "never suggest this to me", which the user meant regardless of
    /// which keyboard mode they were in, and an explicitly added word is
    /// likewise a deliberate statement. Touch statistics are also copied to
    /// both — thumb geometry is a property of the hand, not the language.
    func split(
        configuration: PersonalModel.Configuration = PersonalModel.Configuration()
    ) -> [LearningLanguage: PersonalModel] {
        var result: [LearningLanguage: PersonalModel] = [:]
        for language in LearningLanguage.allCases {
            result[language] = PersonalModel(configuration: configuration)
        }

        var owner: [String: LearningLanguage] = [:]
        for (word, stats) in words {
            let language: LearningLanguage =
                stats.englishCount > stats.icelandicCount ? .english : .icelandic
            owner[word] = language
            result[language]?.adoptWord(word, stats: stats)
        }

        for (key, count) in bigrams {
            // A pair belongs where its first word does; an unattributed first
            // word sends the pair to Icelandic with everything else.
            let first = String(key.split(separator: " ").first ?? "")
            let language = owner[first] ?? .icelandic
            result[language]?.adoptBigram(key, count: count)
        }

        for language in LearningLanguage.allCases {
            result[language]?.adoptShared(
                tombstones: tombstones, userAdded: userAdded, touch: touch)
        }
        return result
    }
}
