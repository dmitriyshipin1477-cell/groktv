import Foundation

// MARK: - Configuration

/// Single place for every API-related constant.
enum APIConfig {
    static let baseURL = URL(string: "https://api.x.ai/v1")!
    static let chatCompletionsURL = baseURL.appendingPathComponent("chat/completions")

    /// The Grok model used for every request.
    static let model = "grok-4.7"

    static let systemPrompt = "You are Grok, a helpful and useful AI built by xAI."

    static let temperature: Double? = nil

    /// Prefer server-sent-event streaming; falls back to a regular request on failure.
    static let useStreaming = true

    static let requestTimeout: TimeInterval = 120

    /// API key injected at build time: Secrets.xcconfig -> XAI_API_KEY build setting -> Info.plist.
    /// For local debugging you may also set an `XAI_API_KEY` environment variable in the scheme.
    static var apiKey: String {
        if let value = Bundle.main.infoDictionary?["XAI_API_KEY"] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !trimmed.hasPrefix("$(") {
                return trimmed
            }
        }
        if let env = ProcessInfo.processInfo.environment["XAI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !env.isEmpty {
            return env
        }
        return ""
    }

    static var hasAPIKey: Bool { !apiKey.isEmpty }
}

// MARK: - Request

struct APIMessage: Codable, Equatable, Sendable {
    let role: String
    let content: String
}

struct ChatCompletionRequest: Encodable, Sendable {
    let model: String
    let messages: [APIMessage]
    let stream: Bool
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(stream, forKey: .stream)
        try container.encodeIfPresent(temperature, forKey: .temperature)
    }
}

// MARK: - Non-streaming response

struct ChatCompletionResponse: Decodable, Sendable {
    struct Choice: Decodable, Sendable {
        struct Message: Decodable, Sendable {
            let role: String?
            let content: String?
        }

        let index: Int?
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }

    let id: String?
    let model: String?
    let choices: [Choice]
}

// MARK: - Streaming chunk

struct ChatCompletionChunk: Decodable, Sendable {
    struct Choice: Decodable, Sendable {
        struct Delta: Decodable, Sendable {
            let role: String?
            let content: String?
        }

        let index: Int?
        let delta: Delta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }

    let id: String?
    let model: String?
    let choices: [Choice]
}

// MARK: - Errors

/// Extracts a human-readable message from xAI error bodies, which may be
/// `{"error": "text"}`, `{"error": {"message": "text"}}`, or plain text.
enum APIErrorResponse {
    static func message(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let text = object["error"] as? String, !text.isEmpty {
                return text
            }
            if let error = object["error"] as? [String: Any],
               let text = error["message"] as? String, !text.isEmpty {
                return text
            }
            if let text = object["message"] as? String, !text.isEmpty {
                return text
            }
            if let text = object["code"] as? String, !text.isEmpty {
                return text
            }
        }
        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return String(text.prefix(500))
        }
        return nil
    }

    /// Returns a message only if the payload is a JSON object containing an `error` key.
    static func errorMessage(inPayload payload: String) -> String? {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["error"] != nil else {
            return nil
        }
        return message(from: data)
    }
}
