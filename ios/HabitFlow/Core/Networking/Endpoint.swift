import Foundation

enum HTTPMethod: String {
    case GET, POST, PATCH, DELETE
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let body: Encodable?
    let requiresAuth: Bool

    private static let baseURL = "http://localhost:8080"

    var url: URL? { URL(string: Self.baseURL + path) }

    // MARK: - Auth
    static func register(name: String, email: String, password: String) -> Endpoint {
        Endpoint(path: "/auth/register", method: .POST,
                 body: ["name": name, "email": email, "password": password],
                 requiresAuth: false)
    }

    static func login(email: String, password: String) -> Endpoint {
        Endpoint(path: "/auth/login", method: .POST,
                 body: ["email": email, "password": password],
                 requiresAuth: false)
    }

    static var logout: Endpoint {
        Endpoint(path: "/auth/logout", method: .POST, body: nil, requiresAuth: true)
    }

    static var me: Endpoint {
        Endpoint(path: "/auth/me", method: .GET, body: nil, requiresAuth: true)
    }

    // MARK: - Habits (Day 2 backend — added as endpoints are ready)
    static var habits: Endpoint {
        Endpoint(path: "/habits", method: .GET, body: nil, requiresAuth: true)
    }

    static func createHabit(name: String, category: String, description: String?) -> Endpoint {
        var b: [String: String] = ["name": name, "category": category]
        if let desc = description { b["description"] = desc }
        return Endpoint(path: "/habits", method: .POST, body: b, requiresAuth: true)
    }

    static func logHabit(id: String) -> Endpoint {
        Endpoint(path: "/habits/\(id)/log", method: .POST, body: nil, requiresAuth: true)
    }

    static func unlogHabit(id: String) -> Endpoint {
        Endpoint(path: "/habits/\(id)/log", method: .DELETE, body: nil, requiresAuth: true)
    }

    static func habitStats(id: String) -> Endpoint {
        Endpoint(path: "/habits/\(id)/stats", method: .GET, body: nil, requiresAuth: true)
    }

    static func deleteHabit(id: String) -> Endpoint {
        Endpoint(path: "/habits/\(id)", method: .DELETE, body: nil, requiresAuth: true)
    }

    static var dashboard: Endpoint {
        Endpoint(path: "/dashboard", method: .GET, body: nil, requiresAuth: true)
    }
}
