import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case conflict(String)
    case badRequest(String)
    case server(Int, String)
    case decoding(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid URL."
        case .unauthorized:        return "Invalid email or password."
        case .conflict(let msg):   return msg
        case .badRequest(let msg): return msg
        case .server(_, let msg):  return msg
        case .decoding(let msg):   return "Decoding error: \(msg)"
        case .unknown:             return "Something went wrong. Please try again."
        }
    }
}
