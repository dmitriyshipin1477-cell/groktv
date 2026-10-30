import SwiftUI

/// One chat bubble. User messages sit on the right, Grok on the left.
/// Bubbles are focusable so the Siri Remote can scroll back through history.
struct MessageBubbleView: View {
    let message: ChatMessage
    var isStreaming: Bool = false

    @FocusState private var isFocused: Bool

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            if isUser {
                Spacer(minLength: 280)
            } else {
                avatar
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 10) {
                Text(isUser ? "You" : "Grok")
                    .font(Theme.labelFont)
                    .foregroundStyle(Theme.secondaryText)

                bubble
            }

            if isUser {
                avatar
            } else {
                Spacer(minLength: 280)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(isUser ? Theme.userBubble : Theme.surface)
            Image(systemName: isUser ? "person.fill" : "sparkles")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(isUser ? Color.white : Color.accentColor)
        }
        .frame(width: 64, height: 64)
        .padding(.top, 34)
    }

    private var bubble: some View {
        Group {
            if message.content.isEmpty && isStreaming {
                HStack(spacing: 16) {
                    ProgressView()
                    Text("Thinking…")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.secondaryText)
                }
            } else {
                Text(renderedContent)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.primaryText)
                    .lineSpacing(8)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(isUser ? Theme.userBubble : Theme.assistantBubble)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(isFocused ? 0.85 : 0), lineWidth: 4)
        )
        .shadow(color: .black.opacity(isFocused ? 0.6 : 0.25), radius: isFocused ? 24 : 8, y: isFocused ? 12 : 4)
        .scaleEffect(isFocused ? 1.03 : 1.0)
        .focusable()
        .focused($isFocused)
        .animation(.easeOut(duration: 0.18), value: isFocused)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUser ? "You" : "Grok"): \(message.content)")
    }

    /// Inline Markdown (bold, italics, code, links) with line breaks preserved.
    private var renderedContent: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: message.content, options: options))
            ?? AttributedString(message.content)
    }
}

#Preview {
    VStack(spacing: 30) {
        MessageBubbleView(message: ChatMessage(role: .user, content: "What's the best sci-fi movie?"))
        MessageBubbleView(message: ChatMessage(role: .assistant, content: "Tough call — **2001: A Space Odyssey** is a strong contender."))
        MessageBubbleView(message: ChatMessage(role: .assistant, content: ""), isStreaming: true)
    }
    .padding(60)
    .background(Color.black)
}
