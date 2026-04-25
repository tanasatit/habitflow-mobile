import Vapor
import Fluent
import FluentPostgresDriver
import JWT

public func configure(_ app: Application) async throws {
    // MARK: Database
    if let urlString = Environment.get("DATABASE_URL"),
       let url = URL(string: urlString),
       var config = try? SQLPostgresConfiguration(url: url) {
        config.coreConfiguration.tls = .disable
        app.databases.use(.postgres(configuration: config), as: .psql)
    } else {
        app.databases.use(
            .postgres(configuration: .init(
                hostname: Environment.get("DATABASE_HOST") ?? "localhost",
                port: Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5433,
                username: Environment.get("DATABASE_USERNAME") ?? "habitflow",
                password: Environment.get("DATABASE_PASSWORD") ?? "habitflow",
                database: Environment.get("DATABASE_NAME") ?? "habitflow",
                tls: .disable
            )),
            as: .psql
        )
    }

    // MARK: JWT
    guard let jwtSecret = Environment.get("JWT_SECRET"), !jwtSecret.isEmpty else {
        throw Abort(.internalServerError, reason: "JWT_SECRET not set")
    }
    await app.jwt.keys.add(hmac: .init(stringLiteral: jwtSecret), digestAlgorithm: .sha256)

    // MARK: Migrations
    app.migrations.add(CreateUser())
    if app.environment != .testing {
        try await app.autoMigrate()
    }

    // MARK: Routes
    try routes(app)
}
