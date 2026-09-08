import Learning
import SwiftUI

/// Settings list of suggestion-bar words hidden via long-press, scoped to
/// one language at a time. Swipe restores a word; the keyboard re-reads the
/// App Group list the next time it appears.
struct HiddenSuggestionsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var language: LearningLanguage = .icelandic

    private var words: [String] {
        appModel.hiddenSuggestions[language] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(
                Strings.Dictionary.languagePickerLabel,
                selection: $language
            ) {
                ForEach(LearningLanguage.allCases) { language in
                    Text(Strings.Dictionary.languageName(language)).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if words.isEmpty {
                ContentUnavailableView(
                    Strings.Settings.hiddenSuggestionsEmpty,
                    systemImage: "eye.slash",
                    description: Text(Strings.Settings.hiddenSuggestionsFooter)
                )
            } else {
                List {
                    ForEach(words, id: \.self) { word in
                        Text(word)
                            .swipeActions(edge: .trailing) {
                                Button(Strings.Settings.hiddenSuggestionsUnhide) {
                                    appModel.unhideSuggestion(word, language: language)
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(Strings.Settings.hiddenSuggestionsNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            language = appModel.language
            appModel.refreshHiddenSuggestions()
        }
    }
}
