import SwiftUI

/// Text input + Send/Stop controls, laid out for Siri Remote focus navigation.
struct ComposerView: View {
    @Binding var text: String
    let isLoading: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    private enum Field: Hashable {
        case input
        case send
        case stop
    }

    @FocusState private var focusedField: Field?

    var body: some View {
        HStack(spacing: 28) {
            TextField("Ask Grok anything…", text: $text)
                .font(Theme.bodyFont)
                .submitLabel(.send)
                .focused($focusedField, equals: .input)
                .disabled(isLoading)
                .onSubmit {
                    guard canSend else { return }
                    onSend()
                }
                .frame(maxWidth: .infinity)

            if isLoading {
                Button(action: onStop) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(Theme.labelFont)
                        .padding(.horizontal, 12)
                }
                .focused($focusedField, equals: .stop)
            } else {
                Button(action: onSend) {
                    Label("Send", systemImage: "paperplane.fill")
                        .font(Theme.labelFont)
                        .padding(.horizontal, 12)
                }
                .disabled(!canSend)
                .focused($focusedField, equals: .send)
            }
        }
        .padding(.vertical, 12)
        .onChange(of: isLoading) { _, loading in
            // Keep focus somewhere sensible when the controls swap.
            focusedField = loading ? .stop : .input
        }
    }
}

#Preview {
    ComposerView(text: .constant("Hello"), isLoading: false, canSend: true, onSend: {}, onStop: {})
        .padding(60)
        .background(Color.black)
}
