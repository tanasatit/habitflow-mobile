import Vapor

func routes(_ app: Application) throws {
    app.get("health") { _ async in
        ["status": "ok"]
    }

    try app.register(collection: AuthController())
    try app.register(collection: HabitController())
    try app.register(collection: DashboardController())
}
