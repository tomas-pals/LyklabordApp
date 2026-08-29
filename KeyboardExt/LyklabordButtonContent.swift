//
//  LyklabordButtonContent.swift
//  LyklabordKeyboard
//
//  Custom key faces. Currently just the adaptive quote key — the spacebar
//  used to double as a signal surface (the armed autocorrect word, plus a
//  DEBUG build stamp) and no longer does: the word space commits now lives
//  in the suggestion bar's centre slot, where it is readable without a thumb
//  over it. See `LyklabordToolbar`.
//

import SwiftUI
import KeyboardKit

/// The adaptive quote key's teaching face (issue #10). In materialized
/// Icelandic mode the key shows BOTH real glyphs spatially — „ low/leading,
/// " high/trailing — with only the character the next tap will insert in the
/// accent blue; the inactive glyph is muted. Glyph position is the primary
/// signal, blue is reinforcement. Neutral/English states never reach this
/// view — the key face is the ordinary centered straight quote.
private struct QuoteKeyFace: View {
    /// The character the next tap inserts: „ (open) or " (close).
    let active: String

    var body: some View {
        ZStack {
            Text(SmartPunctuation.open) // „ — low, leading
                .font(.system(size: 20))
                .foregroundStyle(active == SmartPunctuation.open ? Color.accentColor : Color.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 7)
                .padding(.bottom, 4)
            Text(SmartPunctuation.close) // " — high, trailing
                .font(.system(size: 20))
                .foregroundStyle(active == SmartPunctuation.close ? Color.accentColor : Color.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 7)
                .padding(.top, 2)
        }
        .allowsHitTesting(false)
    }
}

/// The mode key's face: "ÍS", "EN", or the incognito glyph.
///
/// Two-letter language codes rather than flags — the key selects a
/// VOCABULARY, not a country, and a flag would also have to pick one for
/// English. Incognito drops the code entirely for a glyph: it is not a
/// third language, it is a different promise about what the keyboard
/// remembers, and it should not read as one more item in the same list.
private struct ModeKeyFace: View {
    let mode: KeyboardMode

    var body: some View {
        Group {
            if let label = mode.shortLabel {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            } else {
                Image(systemName: KeyboardMode.incognitoSymbolName)
                    .font(.system(size: 17, weight: .regular))
            }
        }
        .allowsHitTesting(false)
    }
}

struct LyklabordButtonContent<Standard: View>: View {
    let action: KeyboardAction
    @ObservedObject var modeContext: KeyboardModeContext
    let standard: Standard

    var body: some View {
        if action == .lyklabordMode {
            ModeKeyFace(mode: modeContext.mode)
        } else if case .character(let char) = action,
            char == SmartPunctuation.open || char == SmartPunctuation.close {
            QuoteKeyFace(active: char)
        } else {
            standard
        }
    }
}
