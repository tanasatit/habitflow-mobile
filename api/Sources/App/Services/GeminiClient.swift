import Vapor
import Foundation

struct GeminiClient: Sendable {
    let apiKey: String

    func generateContent(_ body: GeminiGenerateRequest, on req: Request) async throws -> GeminiGenerateResponse {
        let url = URI(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)")

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(body)

        let response = try await req.client.post(url) { clientReq in
            clientReq.headers.contentType = .json
            clientReq.body = .init(data: jsonData)
        }

        guard response.status == HTTPResponseStatus.ok else {
            let reason = (try? response.content.decode([String: String].self))?["error"] ?? "\(response.status)"
            throw Abort(.badGateway, reason: "Gemini error: \(reason)")
        }

        return try response.content.decode(GeminiGenerateResponse.self)
    }
}
