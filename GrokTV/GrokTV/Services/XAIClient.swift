import Foundation

enum XAIError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidResponse
    case http(status: Int, message: String?)
    case emptyResponse
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No xAI API key found. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig, set XAI_API_KEY, then rebuild."
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .http(status, message):
            let reason: String
            switch status {
            case 400: reason = "Bad request"
            case 401: reason = "Invalid API key"
            case 403: reason = "Access denied"
            case 404: reason = "Model or endpoint not found"
            case 429: reason = "Rate limit or quota reached"
            case 500...599: reason = "xAI server error"
            default: reason = HTTPURLResponse.localizedString(forStatusCode: status).capitalized
            }
            if let message, !message.isEmpty {
                return "\(reason) (\(status)): \(message)"
            }
            return "\(reason) (\(status))."
        case .emptyResponse:
            return "Grok returned an empty response."
        case let .decoding(detail):
            return "Could not read Grok's response: \(detail)"
        }
    }

    /// Errors that a non-streaming retry cannot fix.
    var isFatalForRetry: Bool {
        switch self {
        case .missingAPIKey:
            return true
        case let .http(status, _):
            return [400, 401, 403, 404, 429].contains(status)
        default:
            return false
        }
    }
}

/// Thin client for the xAI chat completions endpoint (OpenAI-compatible).
final class XAIClient: @unchecked Sendable {
    private let session: URLSession
    private let apiKeyProvider: @Sendable () -> String
    let model: String

    init(
        model: String = APIConfig.model,
        session: URLSession = .shared,
        apiKeyProvider: @escaping @Sendable () -> String = { APIConfig.apiKey }
    ) {
        self.model = model
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    // MARK: Request building

    func makeRequest(messages: [APIMessage], stream: Bool) throws -> URLRequest {
        let apiKey = apiKeyProvider()
        guard !apiKey.isEmpty else { throw XAIError.missingAPIKey }

        var request = URLRequest(url: APIConfig.chatCompletionsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = APIConfig.requestTimeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(stream ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")

        let body = ChatCompletionRequest(
            model: model,
            messages: messages,
            stream: stream,
            temperature: APIConfig.temperature
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    // MARK: Non-streaming

    /// Sends the conversation and returns the full assistant reply.
    func complete(messages: [APIMessage]) async throws -> String {
        let request = try makeRequest(messages: messages, stream: false)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw XAIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw XAIError.http(status: http.statusCode, message: APIErrorResponse.message(from: data))
        }

        let decoded: ChatCompletionResponse
        do {
            decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw XAIError.decoding(error.localizedDescription)
        }

        let content = decoded.choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else { throw XAIError.emptyResponse }
        return content
    }

    // MARK: Streaming

    /// Streams the assistant reply as text deltas parsed from SSE `data:` lines.
    func stream(messages: [APIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try self.makeRequest(messages: messages, stream: true)
                    let (bytes, response) = try await self.session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw XAIError.invalidResponse
                    }

                    guard (200...299).contains(http.statusCode) else {
                        var body = Data()
                        for try await byte in bytes {
                            body.append(byte)
                            if body.count >= 64_000 { break }
                        }
                        throw XAIError.http(status: http.statusCode, message: APIErrorResponse.message(from: body))
                    }

                    var parser = SSEParser()
                    var finished = false

                    lineLoop: for try await line in bytes.lines {
                        try Task.checkCancellation()
                        for event in parser.consume(line: line) {
                            if try Self.handle(event, continuation: continuation) {
                                finished = true
                                break lineLoop
                            }
                        }
                    }

                    if !finished {
                        for event in parser.finish() {
                            _ = try Self.handle(event, continuation: continuation)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Yields text for a data event. Returns `true` when the stream is done.
    private static func handle(
        _ event: SSEEvent,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) throws -> Bool {
        switch event {
        case .done:
            return true
        case let .data(payload):
            if let text = SSEParser.deltaText(in: payload) {
                continuation.yield(text)
            } else if let message = APIErrorResponse.errorMessage(inPayload: payload) {
                throw XAIError.http(status: 500, message: message)
            }
            return false
        }
    }
}
