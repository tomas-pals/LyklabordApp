//
//  KeyboardLayout+BottomRowAffordanceTests.swift
//  KeyboardKit
//
//  Regression test for the LyklaborÃ° fork's bottom-row affordances
//  (PLAN.md "Bottom-row affordances"): a `.` key between the spacebar and
//  return on iPhone, with a long-press callout cluster.
//
//  This mirrors `KeyboardLayout_IcelandicRegressionTests`: it duplicates
//  the production types from `KeyboardExt/KeyboardViewController.swift`
//  (`LyklabordIPhoneLayoutService`, `LyklabordLayoutService`, and
//  the "." override in `Callouts.Actions.icelandic`) locally, since that
//  file lives in the `LyklabordKeyboard` app-extension target, which this
//  test target (a Swift package) cannot import. Keep both copies in sync
//  when either changes.
//

import KeyboardKit
import XCTest

// MARK: - Mirrors of KeyboardExt/KeyboardViewController.swift

/// Mirrors `LyklabordIPhoneLayoutService`.
class TestIPhoneLayoutService: KeyboardLayout.iPhoneLayoutService {

    override func bottomActions(
        for context: KeyboardContext
    ) -> KeyboardAction.Row {
        var actions = super.bottomActions(for: context)
        guard context.keyboardType == .alphabetic else { return actions }
        guard let returnIndex = actions.firstIndex(where: { $0.isPrimaryAction }) else { return actions }
        actions.insert(.character("."), at: returnIndex)
        return actions
    }
}

/// Mirrors `LyklabordLayoutService`.
class TestDeviceLayoutService: KeyboardLayout.DeviceBasedLayoutService {

    private lazy var lyklabordIPhoneService: KeyboardLayoutService = TestIPhoneLayoutService(
        alphabeticInputSet: alphabeticInputSet,
        numericInputSet: numericInputSet,
        symbolicInputSet: symbolicInputSet
    )

    override func keyboardLayoutService(
        for context: KeyboardContext
    ) -> KeyboardLayoutService {
        switch context.deviceTypeForKeyboard {
        case .phone: lyklabordIPhoneService
        default: super.keyboardLayoutService(for: context)
        }
    }
}

/// Mirrors the empty "." override in `Callouts.Actions.icelandic`.
private extension Callouts.Actions {
    static var testIcelandicPeriodFlickOnly: Self {
        var actions = Self.english
        actions.actionsDictionary[.character(".")] = []
        return actions
    }
}

/// Mirrors `LyklabordIPhoneLayoutService.insertLanguageModeKey`.
private let testModeKey = KeyboardAction.custom(named: "lyklabord.mode")

private func insertTestLanguageModeKey(_ actions: inout KeyboardAction.Row) {
    guard !actions.contains(testModeKey) else { return }
    if let spaceIndex = actions.firstIndex(of: .space) {
        actions.insert(testModeKey, at: spaceIndex)
        return
    }
    if let domainIndex = actions.firstIndex(where: {
        if case .urlDomain = $0 { return true }
        if case .text = $0 { return true }
        return false
    }) {
        actions.insert(testModeKey, at: domainIndex)
    }
}

/// Mirrors production: mode key on alphabetic + email/url/webSearch.
class TestModeKeyLayoutService: KeyboardLayout.iPhoneLayoutService {
    override func bottomActions(for context: KeyboardContext) -> KeyboardAction.Row {
        var actions = super.bottomActions(for: context)
        switch context.keyboardType {
        case .alphabetic, .email, .url, .webSearch:
            insertTestLanguageModeKey(&actions)
        default:
            break
        }
        return actions
    }
}

class KeyboardLayout_BottomRowAffordanceTests: XCTestCase {

    /// Mirrors `KeyboardLayout.InputSet.icelandic` in
    /// `KeyboardExt/KeyboardViewController.swift`.
    var icelandicInputSet: KeyboardLayout.InputSet {
        .init(rows: [
            .init(chars: "qwertyuiopð"),
            .init(chars: "asdfghjklæö"),
            .init(chars: "zxcvbnmþ", deviceVariations: [.pad: "zxcvbnmþ,."])
        ])
    }

    func makeContext(device: DeviceType) -> KeyboardContext {
        let context = KeyboardContext()
        context.deviceTypeForKeyboard = device
        context.keyboardType = .alphabetic
        context.keyboardCase = .lowercased
        context.needsInputModeSwitchKey = true
        return context
    }

    func makeService() -> TestDeviceLayoutService {
        .init(
            alphabeticInputSet: icelandicInputSet,
            numericInputSet: .numeric,
            symbolicInputSet: .symbolic
        )
    }


    // MARK: - Bottom row structure

    func testIphoneBottomRowIs123GlobeSpacePeriodReturn() {
        let service = makeService()
        let context = makeContext(device: .phone)
        let layout = service.keyboardLayout(for: context)

        let bottomRow = layout.itemRows[3].map(\.action)
        XCTAssertEqual(
            bottomRow,
            [.keyboardType(.numeric), .nextKeyboard, .space, .character("."), .primary(.return)],
            "expected [123][globe][space][.][return] on iPhone with needsInputModeSwitchKey=true"
        )
    }

    func testIphonePeriodKeyOnlyAddedForAlphabeticKeyboardType() {
        let service = makeService()
        let context = makeContext(device: .phone)

        context.keyboardType = .numeric
        var bottomRow = service.keyboardLayout(for: context).itemRows[3].map(\.action)
        XCTAssertFalse(bottomRow.contains(.character(".")), "numeric bottom row already has '.' on its own input rows")

        context.keyboardType = .email
        bottomRow = service.keyboardLayout(for: context).itemRows[3].map(\.action)
        XCTAssertFalse(bottomRow.contains(.character(".")), "email bottom row keeps its own @/…com layout, untouched")
    }

    func testIpadBottomRowIsUnaffected() {
        // PLAN.md decision #3: iPad stays on KeyboardKit's stock layout.
        let service = makeService()
        let context = makeContext(device: .pad)
        let layout = service.keyboardLayout(for: context)

        let bottomRow = layout.itemRows[3].map(\.action)
        XCTAssertFalse(bottomRow.contains(.character(".")), "the iPad bottom row must not gain the iPhone-only period key")
        XCTAssertTrue(bottomRow.contains(.space))
    }


    // MARK: - Period callout

    func testPeriodKeyHasNoActionCallout() {
        let actions = Callouts.Actions.testIcelandicPeriodFlickOnly
        XCTAssertEqual(
            actions.actions(for: .character(".")),
            Optional<[KeyboardAction]>([]),
            "period is flick-only; other marks live on the 123 board"
        )
        XCTAssertFalse(
            Callouts.Actions.english.actions(for: .character("."))?.isEmpty ?? true,
            "sanity: stock English still ships a period callout we must suppress"
        )
    }

    // MARK: - Language key on URL / email / web-search

    func testLanguageModeKeyIsInsertedOnUrlEmailAndWebSearch() {
        let service = TestModeKeyLayoutService(
            alphabeticInputSet: icelandicInputSet,
            numericInputSet: .numeric,
            symbolicInputSet: .symbolic
        )
        let context = makeContext(device: .phone)

        context.keyboardType = .url
        XCTAssertTrue(
            service.keyboardLayout(for: context).itemRows.last?.map(\.action)
                .contains(testModeKey) == true,
            "Safari URL board must keep ÍS/EN"
        )

        context.keyboardType = .email
        XCTAssertTrue(
            service.keyboardLayout(for: context).itemRows.last?.map(\.action)
                .contains(testModeKey) == true,
            "email board must keep ÍS/EN"
        )

        context.keyboardType = .webSearch
        XCTAssertTrue(
            service.keyboardLayout(for: context).itemRows.last?.map(\.action)
                .contains(testModeKey) == true
        )

        context.keyboardType = .numeric
        XCTAssertFalse(
            service.keyboardLayout(for: context).itemRows.last?.map(\.action)
                .contains(testModeKey) == true,
            "123 board is temporary — no language key"
        )
    }

    func testLanguageModeKeySitsBeforeSpaceOrUrlDomain() {
        var withSpace: KeyboardAction.Row = [
            .keyboardType(.numeric), .nextKeyboard, .space, .character("@"), .primary(.return)
        ]
        insertTestLanguageModeKey(&withSpace)
        XCTAssertEqual(
            withSpace,
            [.keyboardType(.numeric), .nextKeyboard, testModeKey, .space, .character("@"), .primary(.return)]
        )

        var urlRow: KeyboardAction.Row = [
            .keyboardType(.numeric), .nextKeyboard, .urlDomain, .character("/"), .text(".com"), .primary(.return)
        ]
        insertTestLanguageModeKey(&urlRow)
        XCTAssertEqual(
            urlRow,
            [.keyboardType(.numeric), .nextKeyboard, testModeKey, .urlDomain, .character("/"), .text(".com"), .primary(.return)]
        )
    }
}
