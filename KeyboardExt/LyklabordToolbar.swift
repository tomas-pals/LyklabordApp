//
//  LyklabordToolbar.swift
//  LyklabordKeyboard
//
//  The autocomplete toolbar. Two Lyklaborð departures from the stock
//  KeyboardKit bar:
//
//  1. EMPTY STATE — with nothing to suggest (idle, or an empty field) the bar
//     would otherwise sit blank, so it becomes a quick strip of the user's
//     most-used emoji (frecency, see EmojiFrequencyStore). Taps route through
//     the shared action handler, so inserting an emoji here also records it
//     back into the frecency store and reuses the same feedback/insert path
//     as every other key. On-device only.
//
//  2. FIXED SLOTS — see `LyklabordToolbar`.
//

import SwiftUI
import KeyboardKit

extension AutocompleteContext {
    /// The literal the user typed, offered as the leftmost icon button.
    var literalSuggestion: Autocomplete.Suggestion? {
        suggestions.first(where: { $0.isUnknown })
    }

    /// The word space will commit: the armed candidate when there is one,
    /// otherwise the literal (space then replaces the token with itself,
    /// i.e. does nothing beyond inserting the space).
    var commitSuggestion: Autocomplete.Suggestion? {
        suggestions.first(where: { $0.isAutocorrect }) ?? literalSuggestion
    }
}

/// The suggestion bar, laid out as a fixed literal button plus three chips.
///
///     [ ⌨︎ ] │  alt₁  │ **commit** │  alt₂
///
/// - **Literal button** (far left) — inserts the token exactly as typed. It
///   is an ICON, not a text chip: the user can already read what they typed
///   in the document, so spelling it out again wasted a candidate slot. This
///   is the escape hatch from an aggressive correction, and tapping it also
///   tells the session to stop correcting that token (`noteVerbatimChoice`).
///
/// - **Commit slot** (centre) — the word the spacebar will insert, always.
///   It used to live on the spacebar itself; a suggestion bar whose middle
///   entry is "what happens if I press space" is easier to read at a glance
///   than a label on the key your thumb is covering. When the engine has
///   nothing armed the slot shows the literal, so the invariant "space types
///   the middle slot" holds with no exceptions.
///
/// - **Alternatives** (left and right of centre) — the next-ranked
///   candidates, in rank order. Personal-learned words keep KeyboardKit's
///   wave-37 long-press-to-eject affordance here.
///
/// An emoji match takes the right-hand alternative's place (KeyboardKit's
/// `Autocomplete.Toolbar` drops one plain candidate when an `.emoji`
/// suggestion is present), so the bar is always the button plus three slots.
struct LyklabordToolbar<Standard: View>: View {

    @ObservedObject var autocompleteContext: AutocompleteContext
    let actionHandler: KeyboardActionHandler
    let suggestionAction: (Autocomplete.Suggestion) -> Void
    let standard: Standard

    var body: some View {
        let all = autocompleteContext.suggestions
        if all.isEmpty {
            EmojiFrecencyRow(actionHandler: actionHandler)
        } else {
            let emoji = all.filter { $0.type == .emoji }
            let literal = autocompleteContext.literalSuggestion
            let commit = autocompleteContext.commitSuggestion
            // Alternatives: everything that is neither the literal button nor
            // already shown in the centre, in rank order.
            let alternatives = all.filter {
                $0.type != .emoji && !$0.isUnknown && $0.text != commit?.text
            }
            HStack(spacing: 0) {
                if let literal {
                    LiteralSuggestionButton(suggestion: literal, action: suggestionAction)
                }
                Autocomplete.Toolbar(
                    suggestions: Self.slots(commit: commit, alternatives: alternatives) + emoji,
                    suggestionAction: suggestionAction
                )
            }
        }
    }

    /// Centre the commit slot between the two highest-ranked alternatives.
    /// With only one alternative the commit slot still sits in the middle
    /// (trailing slot empty) rather than sliding left, so its position never
    /// moves as candidates come and go mid-word.
    static func slots(
        commit: Autocomplete.Suggestion?,
        alternatives: [Autocomplete.Suggestion]
    ) -> [Autocomplete.Suggestion] {
        guard let commit else { return Array(alternatives.prefix(3)) }
        var slots: [Autocomplete.Suggestion] = []
        if let leading = alternatives.first { slots.append(leading) }
        slots.append(commit)
        if alternatives.count > 1 { slots.append(alternatives[1]) }
        return slots
    }
}

/// The leftmost "type it exactly as I wrote it" button. Deliberately quiet —
/// it is an escape hatch, not a suggestion, and it must not compete visually
/// with the commit slot.
private struct LiteralSuggestionButton: View {

    let suggestion: Autocomplete.Suggestion
    let action: (Autocomplete.Suggestion) -> Void

    var body: some View {
        Button {
            action(suggestion)
        } label: {
            Image(systemName: "character.cursor.ibeam")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.primary.opacity(0.75))
                .frame(width: 40, height: LyklabordKeyboardMetrics.toolbarHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Nota stafrétt")
        .accessibilityValue(suggestion.text)
    }
}

/// A single row of the top frecency emoji, spread evenly across the toolbar
/// width. Recomputed each time the bar transitions to empty (the enclosing
/// `if` recreates it), so it reflects recent use without reordering mid-view.
private struct EmojiFrecencyRow: View {

    let actionHandler: KeyboardActionHandler
    private let emojis = EmojiFrequencyStore.shared.top(8)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(emojis, id: \.self) { emoji in
                Button {
                    actionHandler.handle(.release, on: .emoji(KeyboardKit.Emoji(emoji)))
                } label: {
                    Text(emoji)
                        .font(.system(size: 22))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: LyklabordKeyboardMetrics.toolbarHeight)
    }
}
