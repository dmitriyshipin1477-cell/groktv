import Foundation

/// A parsed server-sent event relevant to the chat completions stream.
enum SSEEvent: Equatable, Sendable {
    /// The payload of a `data:` field (JSON chunk).
    case data(String)
    /// The `data: [DONE]` terminator.
    case done
}

/// Minimal SSE parser for OpenAI-compatible streaming endpoints.
///
/// Feed it lines one at a time. `data:` lines are buffered and emitted when a blank
/// line ends the event. Because `URLSession.AsyncBytes.lines` drops blank lines,
/// a complete JSON payload on a single `data:` line is also emitted immediately.
struct SSEParser {
    private var dataLines: [String] = []

    init() {}

    /// Processes one line (without its trailing newline) and returns any completed events.
    mutating func consume(line rawLine: String) -> [SSEEvent] {
        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine

        // Blank line: dispatch the buffered event.
        if line.isEmpty {
            return flush()
        }

        // Comment / keep-alive line.
        if line.hasPrefix(":") {
            return []
        }

        guard let value = Self.fieldValue(named: "data", in: line) else {
            // Other fields (event:, id:, retry:) are not needed for chat completions.
            return []
        }

        if value == "[DONE]" {
            var events = flush()
            events.append(.done)
            return events
        }

        dataLines.append(value)

        // Single-line JSON payloads are emitted right away (lines() strips blank separators).
        if dataLines.count == 1, Self.looksLikeCompleteJSON(value) {
            return flush()
        }
        if dataLines.count > 1, Self.looksLikeCompleteJSON(dataLines.joined(separator: "\n")) {
            return flush()
        }
        return []
    }

    /// Emits whatever is still buffered (call when the stream ends).
    mutating func finish() -> [SSEEvent] {
        flush()
    }

    private mutating func flush() -> [SSEEvent] {
        guard !dataLines.isEmpty else { return [] }
        let payload = dataLines.joined(separator: "\n")
        dataLines.removeAll()
        if payload == "[DONE]" { return [.done] }
        return [.data(payload)]
    }

    private static func fieldValue(named name: String, in line: String) -> String? {
        let prefix = name + ":"
        guard line.hasPrefix(prefix) else { return nil }
        var value = Substring(line.dropFirst(prefix.count))
        if value.hasPrefix(" ") { value = value.dropFirst() }
        return String(value)
    }

    private static func looksLikeCompleteJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    // MARK: - Chunk decoding

    private static let decoder = JSONDecoder()

    /// Decodes a `data:` payload into a streaming chunk.
    static func decodeChunk(_ payload: String) throws -> ChatCompletionChunk {
        guard let data = payload.data(using: .utf8) else {
            throw XAIError.decoding("Stream payload was not valid UTF-8.")
        }
        return try decoder.decode(ChatCompletionChunk.self, from: data)
    }

    /// Returns the text delta in a payload, if any.
    static func deltaText(in payload: String) -> String? {
        guard let chunk = try? decodeChunk(payload) else { return nil }
        let text = chunk.choices.compactMap { $0.delta.content }.joined()
        return text.isEmpty ? nil : text
    }
}
