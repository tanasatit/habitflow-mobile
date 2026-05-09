import Foundation

// Shared API client — call via APIClient.shared.send(endpoint, token:)
final class APIClient: Sendable {
    static let shared = APIClient()
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func send<T: Decodable>(_ endpoint: Endpoint, token: String? = nil) async throws -> T {
        guard let url = endpoint.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        switch status {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error.localizedDescription)
            }
        case 400:
            let msg = (try? decoder.decode(VaporError.self, from: data))?.reason ?? "Bad request."
            throw APIError.badRequest(msg)
        case 401:
            throw APIError.unauthorized
        case 409:
            let msg = (try? decoder.decode(VaporError.self, from: data))?.reason ?? "Already exists."
            throw APIError.conflict(msg)
        default:
            let msg = (try? decoder.decode(VaporError.self, from: data))?.reason ?? "Server error."
            throw APIError.server(status, msg)
        }
    }

    // Void response variant (e.g. logout 204)
    func sendVoid(_ endpoint: Endpoint, token: String? = nil) async throws {
        guard let url = endpoint.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body = endpoint.body { request.httpBody = try encoder.encode(AnyEncodable(body)) }

        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw APIError.unauthorized }
    }
}

// Vapor error response shape: {"error":true,"reason":"..."}
private struct VaporError: Decodable {
    let reason: String
}

// Type-erased Encodable wrapper
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ value: Encodable) { _encode = value.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
