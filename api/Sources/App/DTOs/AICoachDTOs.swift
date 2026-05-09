import Vapor

// MARK: - Chat API (client-facing)

struct ChatRequest: Content, Sendable {
    let message: String
}

struct CreatedEventResponse: Content, Sendable {
    let title: String
    let startTime: Date
}

struct ChatResponse: Content, Sendable {
    let reply: String
    let calendarUpdated: Bool
    let events: [CreatedEventResponse]?
}

// MARK: - Gemini wire types

struct GeminiSystemInstruction: Encodable, Sendable {
    let parts: [GeminiPart]
}

struct GeminiGenerateRequest: Encodable, Sendable {
    let systemInstruction: GeminiSystemInstruction?
    let tools: [GeminiTool]
    var contents: [GeminiContent]
}

struct GeminiGenerateResponse: Decodable, Sendable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Decodable, Sendable {
    let content: GeminiContent
}

struct GeminiContent: Codable, Sendable {
    let role: String
    let parts: [GeminiPart]
}

struct GeminiPart: Codable, Sendable {
    let text: String?
    let functionCall: GeminiFunctionCall?
    let functionResponse: GeminiFunctionResponse?

    init(text: String) {
        self.text = text
        self.functionCall = nil
        self.functionResponse = nil
    }
    init(functionResponse: GeminiFunctionResponse) {
        self.text = nil
        self.functionCall = nil
        self.functionResponse = functionResponse
    }

    private enum CodingKeys: String, CodingKey {
        case text, functionCall, functionResponse
    }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(functionCall, forKey: .functionCall)
        try c.encodeIfPresent(functionResponse, forKey: .functionResponse)
    }
}

struct GeminiFunctionCall: Codable, Sendable {
    let name: String
    let args: GeminiFunctionCallArgs
}

struct GeminiFunctionCallArgs: Codable, Sendable {
    let events: [GeminiCalendarEventArg]?

    private enum CodingKeys: String, CodingKey { case events }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(events, forKey: .events)
    }
}

struct GeminiCalendarEventArg: Codable, Sendable {
    let title: String
    let startAt: String
    let endAt: String
    let notes: String?

    private enum CodingKeys: String, CodingKey { case title, startAt, endAt, notes }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(startAt, forKey: .startAt)
        try c.encode(endAt, forKey: .endAt)
        try c.encodeIfPresent(notes, forKey: .notes)
    }
}

struct GeminiFunctionResponse: Codable, Sendable {
    let name: String
    let response: [String: String]
}

struct GeminiTool: Encodable, Sendable {
    let functionDeclarations: [GeminiFunctionDeclaration]
}

struct GeminiFunctionDeclaration: Encodable, Sendable {
    let name: String
    let description: String
    let parameters: GeminiParameters
}

struct GeminiParameters: Encodable, Sendable {
    let type: String
    let properties: [String: GeminiProperty]
    let required: [String]
}

struct GeminiProperty: Encodable, Sendable {
    let type: String
    let description: String?
    let items: GeminiItems?

    init(type: String, description: String? = nil, items: GeminiItems? = nil) {
        self.type = type; self.description = description; self.items = items
    }

    private enum CodingKeys: String, CodingKey { case type, description, items }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(items, forKey: .items)
    }
}

struct GeminiItems: Encodable, Sendable {
    let type: String
    let properties: [String: GeminiProperty]?
    let required: [String]?

    private enum CodingKeys: String, CodingKey { case type, properties, required }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(properties, forKey: .properties)
        try c.encodeIfPresent(required, forKey: .required)
    }
}
