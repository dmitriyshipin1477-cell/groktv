import SwiftUI

/// Welcome screen shown before the first message, with quick-start prompts.
struct EmptyStateView: View {
    var hasAPIKey: Bool = true
    let onSelectPrompt: (String) -> Void

    private struct Suggestion: Identifiable {
        let icon: String
        let title: String
        let prompt: String
        var id: String { title }
    }

    private let suggestions: [Suggestion] = [
        Suggestion(icon: "film", title: "Movie night", prompt: "Recommend three great movies for a cozy movie night, with a one-line pitch for each."),
        Suggestion(icon: "lightbulb", title: "Explain it", prompt: "Explain how black holes work as if I were ten years old."),
        Suggestion(icon: "fork.knife", title: "Dinner ideas", prompt: "Give me a quick, tasty dinner idea I can make in 30 minutes."),
        Suggestion(icon: "face.smiling", title: "Make me laugh", prompt: "Tell me a genuinely funny joke about space.")
    ]

    var body: some View {
        VStack(spacing: 36) {
            Spacer(minLength: 0)

            Image(systemName: "sparkles")
                .font(.system(size: 110, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .shadow(color: Color.accentColor.opacity(0.5), radius: 40)

            Text("Chat with Grok")
                .font(Theme.heroFont)
                .foregroundStyle(Theme.primaryText)

            Text(hasAPIKey
                 ? "Ask anything. Pick a suggestion or type below with your Siri Remote."
                 : "Add your xAI API key to Config/Secrets.xcconfig and rebuild to start chatting.")
                .font(.system(size: 32))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 1200)

            HStack(spacing: 36) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelectPrompt(suggestion.prompt)
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            Image(systemName: suggestion.icon)
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                            Text(suggestion.title)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(Theme.primaryText)
                        }
                        .frame(width: 300, height: 170, alignment: .leading)
                        .padding(24)
                        .background(Theme.surface)
                    }
                    .buttonStyle(.card)
                    .disabled(!hasAPIKey)
                }
            }
            .padding(.top, 20)

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    EmptyStateView { _ in }
        .background(Color.black)
}
