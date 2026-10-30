import Foundation
import SwiftUI

/// Owns the chat session: transcript, composer draft, loading and error state.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// ID of the assistant message currently being written, if any.
    @Published private(set) var streamingMessageID: UUID?

    private let client: XAIClient
    private let useStreaming: Bool
    private var currentTask: Task<Void, Never>?

    init(client: XAIClient = XAIClient(), useStreaming: Bool = APIConfig.useStreaming) {
        self.client = client
        self.useStreaming = useStreaming
    }

    var canSend: Bool {
        !isLoading && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasAPIKey: Bool { APIConfig.hasAPIKey }

    // MARK: Intents

    func sendDraft() {
        let text = draft
        guard send(text) else { return }
        draft = ""
    }

    /// Sends a user message. Returns `false` if nothing was sent.
    @discardableResult
    func send(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return false }

        guard APIConfig.hasAPIKey else {
            errorMessage = XAIError.missingAPIKey.localizedDescription
            return false
        }

        errorMessage = nil
        messages.append(ChatMessage(role: .user, content: trimmed))

        let history = buildHistory()
        let placeholder = ChatMessage(role: .assistant, content: "")
        messages.append(placeholder)
        streamingMessageID = placeholder.id
        isLoading = true

        currentTask = Task { [weak self] in
            await self?.respond(history: history, assistantID: placeholder.id)
        }
        return true
    }

    /// Cancels the in-flight reply, keeping any text already received.
    func stop() {
        currentTask?.cancel()
    }

    /// Clears the session history.
    func newConversation() {
        currentTask?.cancel()
        currentTask = nil
        messages.removeAll()
        draft = ""
        errorMessage = nil
        isLoading = false
        streamingMessageID = nil
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: Networking

    private func buildHistory() -> [APIMessage] {
        var history = [APIMessage(role: ChatMessage.Role.system.rawValue, content: APIConfig.systemPrompt)]
        history += messages
            .filter { $0.role != .system && !$0.content.isEmpty }
            .map(\.apiMessage)
        return history
    }

    private func respond(history: [APIMessage], assistantID: UUID) async {
        do {
            if useStreaming {
                try await streamReply(history: history, assistantID: assistantID)
            } else {
                let reply = try await client.complete(messages: history)
                setContent(reply, for: assistantID)
            }
        } catch {
            handle(error, assistantID: assistantID)
        }

        // Ignore completion of a task that was superseded (e.g. by "New Chat").
        guard streamingMessageID == assistantID else { return }
        isLoading = false
        streamingMessageID = nil
        currentTask = nil
    }

    private func streamReply(history: [APIMessage], assistantID: UUID) async throws {
        do {
            var receivedAny = false
            for try await delta in client.stream(messages: history) {
                receivedAny = true
                append(delta, to: assistantID)
            }
            if Task.isCancelled { throw CancellationError() }
            if !receivedAny {
                // Stream ended without content: fall back to a plain request.
                let reply = try await client.complete(messages: history)
                setContent(reply, for: assistantID)
            }
        } catch {
            guard shouldFallBack(after: error, assistantID: assistantID) else { throw error }
            let reply = try await client.complete(messages: history)
            setContent(reply, for: assistantID)
        }
    }

    private func shouldFallBack(after error: Error, assistantID: UUID) -> Bool {
        if Task.isCancelled || Self.isCancellation(error) { return false }
        if let xaiError = error as? XAIError, xaiError.isFatalForRetry { return false }
        // Only retry if nothing was streamed yet, so we never duplicate text.
        return content(of: assistantID).isEmpty
    }

    private func handle(_ error: Error, assistantID: UUID) {
        guard streamingMessageID == assistantID else { return }
        if Self.isCancellation(error) || Task.isCancelled {
            removeIfEmpty(assistantID)
            return
        }
        removeIfEmpty(assistantID)
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    // MARK: Transcript mutation

    private func index(of id: UUID) -> Int? {
        messages.lastIndex { $0.id == id }
    }

    private func content(of id: UUID) -> String {
        index(of: id).map { messages[$0].content } ?? ""
    }

    private func append(_ text: String, to id: UUID) {
        guard let i = index(of: id) else { return }
        messages[i].content += text
    }

    private func setContent(_ text: String, for id: UUID) {
        guard let i = index(of: id) else { return }
        messages[i].content = text
    }

    private func removeIfEmpty(_ id: UUID) {
        guard let i = index(of: id) else { return }
        if messages[i].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.remove(at: i)
        }
    }
}
