import Vapor

func routes(_ app: Application) throws {
    app.get("health") { _ async in
        ["status": "ok"]
    }

    try app.register(collection: AuthController())
}
