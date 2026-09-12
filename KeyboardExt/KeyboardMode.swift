//
//  KeyboardMode.swift
//  LyklabordKeyboard
//
//  The language/privacy mode key that sits between the emoji key and the
//  spacebar. Unlike `SpacebarMode` (app writes, extension reads), this
//  setting is toggled FROM the keyboard, so the extension is the writer and
//  the containing app reads it back — the dictionary editor uses it to pick
//  which language's store to open first.
//

import Combine
import Foundation
import KeyboardKit
import Learning
import TypeEngine

/// The language the keyboard is typing in.
///
/// This is `Learning.LearningLanguage` rather than a keyboard-side enum of
/// its own: the language IS the personal store it learns into, and a second
/// enum with the same two cases would only be a place for the two raw values
/// to drift apart. Only the vocabulary changes when it flips — the Icelandic
/// layout, callouts and quote behavior stay put in both modes, because the
/// physical keys you reach for should not move when you switch languages
/// mid-sentence.
extension LearningLanguage {
    /// The mode key's face.
    var shortLabel: String {
        switch self {
        case .icelandic: "ÍS"
        case .english: "EN"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .icelandic: "Íslenska"
        case .english: "Enska"
        }
    }

    /// The engine's lexicon pin — what makes suggestions stop crossing.
    var pinned: EngineConfig.PinnedLanguage {
        switch self {
        case .icelandic: .icelandic
        case .english: .english
        }
    }

    var toggled: LearningLanguage {
        switch self {
        case .icelandic: .english
        case .english: .icelandic
        }
    }

    static func from(pinned: EngineConfig.PinnedLanguage) -> LearningLanguage {
        switch pinned {
        case .icelandic: .icelandic
        case .english: .english
        }
    }
}

/// What the mode key is currently showing.
///
/// Tap flips **ÍS ↔ EN**. Long-press enters or leaves huliðshamur
/// (incognito) without changing language — incognito is not a third tap
/// state. Incognito keeps whichever language was last selected, so it
/// reads that language's dictionaries normally and simply writes nothing.
struct KeyboardMode: Equatable {
    var language: LearningLanguage
    var isIncognito: Bool

    static let `default` = KeyboardMode(language: .icelandic, isIncognito: false)

    /// The key's face: the language code, or the incognito glyph.
    var shortLabel: String? { isIncognito ? nil : language.shortLabel }

    /// SF Symbol shown instead of the label while incognito.
    static let incognitoSymbolName = "eyeglasses"

    var accessibilityLabel: String {
        isIncognito ? "Huliðshamur" : language.accessibilityLabel
    }

    /// Tap: ÍS ↔ EN. Incognito is unchanged.
    func cycled() -> KeyboardMode {
        KeyboardMode(language: language.toggled, isIncognito: isIncognito)
    }

    /// Long press: incognito on/off without disturbing the language.
    func togglingIncognito() -> KeyboardMode {
        KeyboardMode(language: language, isIncognito: !isIncognito)
    }

    func selecting(_ language: LearningLanguage) -> KeyboardMode {
        KeyboardMode(language: language, isIncognito: isIncognito)
    }
}

extension Keyboard.KeyboardType {
    /// Letter-row boards that must keep the ÍS/EN key. Numeric / symbolic
    /// / emoji are temporary surfaces; email / URL / web-search are not.
    var showsLanguageModeKey: Bool {
        switch self {
        case .alphabetic, .email, .url, .webSearch: true
        default: false
        }
    }
}

extension KeyboardAction {
    /// The mode key, between the emoji key and the spacebar.
    ///
    /// `.custom` is KeyboardKit's escape hatch for actions it knows nothing
    /// about: it has no standard gesture action, so `StandardActionHandler`
    /// falls through after firing feedback and `LyklabordActionHandler` owns
    /// the behavior outright. Its face and its button style are likewise
    /// supplied by us (`LyklabordButtonContent`, and the style builder in
    /// `KeyboardViewController`, which borrows the emoji key's).
    static let lyklabordMode = KeyboardAction.custom(named: "lyklabord.mode")
}

/// The mode key's observable state.
///
/// `LyklabordAutocompleteService` holds the authoritative copy behind its
/// lock (the engine queue reads it on every learning flush), but SwiftUI
/// needs something to observe for the key's face — hence this thin
/// main-thread mirror. Writes go through here so the two can never drift:
/// the view reads `mode`, the action handler calls `cycle()`/
/// `toggleIncognito()`, and both paths push into the service. The
/// wrong-language chip also lives here (`suggestedLanguageSwitch`).
///
/// Main thread only, like every `ObservableObject` driving a rendered view.
/// Every caller already is one: the controller's `viewDidLoad` /
/// `viewWillAppear` and the action handler's gesture path.
final class KeyboardModeContext: ObservableObject {

    @Published private(set) var mode: KeyboardMode = .default

    /// Other language the current token looks like. Shown as a chip above
    /// the suggestion bar; nil when the token matches the pinned lexicon.
    @Published private(set) var suggestedLanguageSwitch: LearningLanguage?

    private weak var service: LyklabordAutocompleteService?

    init(service: LyklabordAutocompleteService?) {
        self.service = service
    }

    /// Adopt whatever the App Group suite holds. Called on every keyboard
    /// presentation, so a mode left set in an earlier session is restored.
    func refreshFromDefaults(appGroupId: String?) {
        apply(KeyboardMode.current(appGroupId: appGroupId))
    }

    /// Tap: ÍS ↔ EN.
    func cycle() {
        apply(mode.cycled())
    }

    /// Long press: incognito on/off, language untouched.
    func toggleIncognito() {
        apply(mode.togglingIncognito())
    }

    func selectLanguage(_ language: LearningLanguage) {
        apply(mode.selecting(language))
    }

    func acceptSuggestedLanguageSwitch() {
        guard let language = suggestedLanguageSwitch else { return }
        apply(mode.selecting(language))
    }

    /// Main-thread only — called from the autocomplete service after each pass.
    func setSuggestedLanguageSwitch(_ language: LearningLanguage?) {
        guard suggestedLanguageSwitch != language else { return }
        suggestedLanguageSwitch = language
    }

    private func apply(_ new: KeyboardMode) {
        guard new != mode else { return }
        mode = new
        service?.setKeyboardMode(new)
    }
}

extension KeyboardMode {
    /// Raw-value keys in the App Group `UserDefaults` suite. The language
    /// key is mirrored in `App/AppModel.swift` — the app cannot import
    /// extension code, so that one string has to stay identical on both
    /// sides (same arrangement as `SpacebarMode`). The stored value is a
    /// `LearningLanguage` raw value, which both sides do share.
    static let languageDefaultsKey = "is.solberg.lyklabord.settings.keyboardLanguage"
    static let incognitoDefaultsKey = "is.solberg.lyklabord.settings.incognito"

    /// Read the mode from the App Group suite. Degrades to Icelandic,
    /// non-incognito on any failure (no Full Access, no suite, no value) —
    /// the same graceful-default doctrine as `SpacebarMode.current`.
    static func current(appGroupId: String?) -> KeyboardMode {
        guard let appGroupId, let defaults = UserDefaults(suiteName: appGroupId) else {
            return .default
        }
        let language =
            defaults.string(forKey: languageDefaultsKey)
            .flatMap(LearningLanguage.init(rawValue:)) ?? .icelandic
        return KeyboardMode(
            language: language,
            isIncognito: defaults.bool(forKey: incognitoDefaultsKey)
        )
    }

    /// Persist the mode so it survives the extension being torn down between
    /// host apps, and so the containing app's dictionary editor opens on the
    /// language actually in use.
    func write(appGroupId: String?) {
        guard let appGroupId, let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.set(language.rawValue, forKey: Self.languageDefaultsKey)
        defaults.set(isIncognito, forKey: Self.incognitoDefaultsKey)
    }
}
