import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()

    private let bottomAnchorID = "chat-bottom-anchor"

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                header

                if viewModel.messages.isEmpty {
                    EmptyStateView(hasAPIKey: viewModel.hasAPIKey) { prompt in
                        _ = viewModel.send(prompt)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    messageList
                }

                ComposerView(
                    text: $viewModel.draft,
                    isLoading: viewModel.isLoading,
                    canSend: viewModel.canSend,
                    onSend: { viewModel.sendDraft() },
                    onStop: { viewModel.stop() }
                )
            }
            .padding(.horizontal, 40)

            if let message = viewModel.errorMessage {
                ErrorBannerView(message: message, onDismiss: { viewModel.dismissError() })
                    .padding(.horizontal, 120)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.errorMessage)
        .animation(.easeInOut(duration: 0.25), value: viewModel.messages.isEmpty)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Color.accentColor)
            Text("Grok")
                .font(Theme.titleFont)
                .foregroundStyle(Theme.primaryText)
            Text(APIConfig.model)
                .font(Theme.labelFont)
                .foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.surface))

            Spacer()

            if viewModel.isLoading {
                HStack(spacing: 14) {
                    ProgressView()
                    Text("Grok is thinking…")
                        .font(Theme.labelFont)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Button {
                viewModel.newConversation()
            } label: {
                Label("New Chat", systemImage: "plus.bubble")
                    .font(Theme.labelFont)
            }
            .disabled(viewModel.messages.isEmpty)
        }
    }

    // MARK: Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 32) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isStreaming: message.id == viewModel.streamingMessageID
                        )
                        .id(message.id)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
            .onAppear {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.messages.last?.content) { _, _ in
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        }
    }
}

#Preview {
    ChatView()
}
