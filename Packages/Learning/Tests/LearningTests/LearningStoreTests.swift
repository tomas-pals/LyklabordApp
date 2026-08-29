import XCTest

@testable import Learning

/// Per-language personal stores and the one-time split of the legacy files.
final class LearningStoreTests: XCTestCase {

    private var container: URL!

    override func setUpWithError() throws {
        container = FileManager.default.temporaryDirectory
            .appendingPathComponent("learning-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: container)
    }

    private func url(_ name: String) -> URL { container.appendingPathComponent(name) }

    private func model(_ language: LearningLanguage) throws -> PersonalModel {
        try PersonalModel(contentsOf: url(language.personalModelFileName))
    }

    private func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(name).path)
    }

    // MARK: - File naming

    func testEachLanguageOwnsDistinctFiles() {
        let names = LearningLanguage.allCases.flatMap {
            [$0.personalModelFileName, $0.eventLogFileName]
        }
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertEqual(LearningLanguage.icelandic.personalModelFileName, "personal-model-is.json")
        XCTAssertEqual(LearningLanguage.english.eventLogFileName, "learning-events-en.log")
    }

    func testUnknownAttributionFilesUnderIcelandic() {
        XCTAssertEqual(LearningLanguage.owning(.unknown), .icelandic)
        XCTAssertEqual(LearningLanguage.owning(.icelandic), .icelandic)
        XCTAssertEqual(LearningLanguage.owning(.english), .english)
    }

    // MARK: - Migration

    /// Build a legacy store: two Icelandic-attributed words, one English, one
    /// tombstone, one user-added word, and a bigram in each language.
    private func writeLegacyModel() throws -> PersonalModel {
        let legacy = PersonalModel()
        let log = EventLog(url: url("seed.log"))
        try log.append(contentsOf: [
            .wordCommitted(word: "þingmaður", previousWord: nil, languageHint: .icelandic),
            .wordCommitted(word: "hestur", previousWord: "þingmaður", languageHint: .icelandic),
            .wordCommitted(word: "deadline", previousWord: nil, languageHint: .english),
            .wordCommitted(word: "standup", previousWord: "deadline", languageHint: .english),
        ])
        try legacy.compact(applying: log)
        legacy.remove(word: "ruslorð")
        try legacy.addUserWord("Sólberg")
        try legacy.save(to: url(LearningStoreMigration.legacyPersonalModelFileName))
        return legacy
    }

    func testMigrationRoutesWordsToTheirAttributedLanguage() throws {
        _ = try writeLegacyModel()
        let summary = try LearningStoreMigration.run(in: container)
        XCTAssertTrue(summary.migrated)

        let icelandic = try model(.icelandic)
        let english = try model(.english)

        XCTAssertEqual(icelandic.commitCount(of: "þingmaður"), 1)
        XCTAssertEqual(icelandic.commitCount(of: "hestur"), 1)
        XCTAssertEqual(icelandic.commitCount(of: "deadline"), 0, "English word must not be here")

        XCTAssertEqual(english.commitCount(of: "deadline"), 1)
        XCTAssertEqual(english.commitCount(of: "standup"), 1)
        XCTAssertEqual(english.commitCount(of: "hestur"), 0, "Icelandic word must not be here")
    }

    func testMigrationKeepsBigramsWithTheirFirstWord() throws {
        _ = try writeLegacyModel()
        try LearningStoreMigration.run(in: container)

        XCTAssertEqual(try model(.icelandic).bigramFrequency("þingmaður", "hestur"), 1)
        XCTAssertNil(try model(.icelandic).bigramFrequency("deadline", "standup"))
        XCTAssertEqual(try model(.english).bigramFrequency("deadline", "standup"), 1)
        XCTAssertNil(try model(.english).bigramFrequency("þingmaður", "hestur"))
    }

    func testMigrationCopiesDeliberateStatementsToBothStores() throws {
        _ = try writeLegacyModel()
        try LearningStoreMigration.run(in: container)

        for language in LearningLanguage.allCases {
            let store = try model(language)
            XCTAssertTrue(store.isTombstoned("ruslorð"), "\(language) lost the tombstone")
            XCTAssertTrue(store.isUserAdded("Sólberg"), "\(language) lost the user-added word")
        }
    }

    func testMigrationAppliesUnconsumedEventsWithTheirOriginalDays() throws {
        // A legacy model that has NOT consumed its log yet. "nýyrði" was
        // committed on two distinct days, so it must arrive already learned —
        // re-appending the events today would have collapsed both onto one
        // bucket and left it below the threshold.
        let legacyLog = EventLog(url: url(LearningStoreMigration.legacyEventLogFileName))
        var day: Int32 = 20_000
        var log = legacyLog
        log.dayProvider = { day }
        try log.append(.wordCommitted(word: "nýyrði", previousWord: nil, languageHint: .icelandic))
        day = 20_001
        try log.append(.wordCommitted(word: "nýyrði", previousWord: nil, languageHint: .icelandic))
        try log.append(.wordCommitted(word: "sprint", previousWord: nil, languageHint: .english))
        try PersonalModel().save(to: url(LearningStoreMigration.legacyPersonalModelFileName))

        let summary = try LearningStoreMigration.run(in: container)
        XCTAssertEqual(summary.eventCounts[.icelandic], 2)
        XCTAssertEqual(summary.eventCounts[.english], 1)

        XCTAssertTrue(
            try model(.icelandic).isLearned("nýyrði"),
            "two distinct day buckets must survive the migration")
        XCTAssertFalse(try model(.english).isLearned("sprint"), "one day is below the threshold")
    }

    func testMigrationRemovesLegacyFilesAndIsIdempotent() throws {
        _ = try writeLegacyModel()
        try LearningStoreMigration.run(in: container)
        XCTAssertFalse(exists(LearningStoreMigration.legacyPersonalModelFileName))
        XCTAssertFalse(exists(LearningStoreMigration.legacyEventLogFileName))

        let second = try LearningStoreMigration.run(in: container)
        XCTAssertFalse(second.migrated)
        XCTAssertEqual(try model(.icelandic).commitCount(of: "þingmaður"), 1, "not double-applied")
    }

    /// The app and the extension both call `runCoordinated` on startup, so
    /// the second caller must be the one that finds nothing left to do. The
    /// file coordinator this wraps only serializes them on Darwin, but the
    /// once-only outcome is `run`'s own `alreadySplit` guard and holds here.
    func testCoordinatedMigrationSplitsOnceAndThenNoOps() throws {
        _ = try writeLegacyModel()

        let first = try LearningStoreMigration.runCoordinated(in: container)
        XCTAssertTrue(first.migrated)
        XCTAssertEqual(first.wordCounts[.english], 2)

        let second = try LearningStoreMigration.runCoordinated(in: container)
        XCTAssertFalse(second.migrated, "the second caller finds the legacy files gone")
        XCTAssertEqual(
            try model(.icelandic).commitCount(of: "þingmaður"), 1, "not applied twice")
    }

    /// The wrapper coordinates on the legacy log, which may not exist — the
    /// overwhelmingly common case, since every launch after the first has
    /// nothing to migrate. A missing file must not turn into a thrown error.
    func testCoordinatedMigrationToleratesAMissingLegacyLog() throws {
        let summary = try LearningStoreMigration.runCoordinated(in: container)
        XCTAssertFalse(summary.migrated)
    }

    func testMigrationDoesNothingWithoutLegacyFiles() throws {
        let summary = try LearningStoreMigration.run(in: container)
        XCTAssertFalse(summary.migrated)
        XCTAssertFalse(exists(LearningLanguage.icelandic.personalModelFileName))
    }

    func testAlreadySplitStoresAreNeverOverwritten() throws {
        let existing = PersonalModel()
        try existing.addUserWord("varðveitt")
        try existing.save(to: url(LearningLanguage.icelandic.personalModelFileName))
        _ = try writeLegacyModel()

        let summary = try LearningStoreMigration.run(in: container)
        XCTAssertFalse(summary.migrated)
        XCTAssertTrue(try model(.icelandic).isUserAdded("varðveitt"))
        XCTAssertEqual(try model(.icelandic).commitCount(of: "þingmaður"), 0)
        XCTAssertFalse(exists(LearningStoreMigration.legacyPersonalModelFileName))
    }

    // MARK: - Independence

    func testTheTwoStoresCompactWithoutSeeingEachOther() throws {
        let icelandic = PersonalModel()
        let english = PersonalModel()
        let icelandicLog = EventLog(url: url(LearningLanguage.icelandic.eventLogFileName))
        let englishLog = EventLog(url: url(LearningLanguage.english.eventLogFileName))

        try icelandicLog.append(
            .wordCommitted(word: "þingmaður", previousWord: nil, languageHint: .icelandic))
        try englishLog.append(
            .wordCommitted(word: "deadline", previousWord: nil, languageHint: .english))

        try icelandic.compact(applying: icelandicLog)
        try english.compact(applying: englishLog)

        XCTAssertEqual(icelandic.commitCount(of: "þingmaður"), 1)
        XCTAssertEqual(icelandic.commitCount(of: "deadline"), 0)
        XCTAssertEqual(english.commitCount(of: "deadline"), 1)
        XCTAssertEqual(english.commitCount(of: "þingmaður"), 0)
    }
}
