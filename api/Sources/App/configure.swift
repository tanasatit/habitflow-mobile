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
    app.migrations.add(CreateHabit())
    app.migrations.add(CreateHabitLog())
    app.migrations.add(AddUniqueHabitLogPerDay())
    app.migrations.add(CreateCalendarEvent())
    if app.environment != .testing {
        try await app.autoMigrate()
    }

    // MARK: Admin Seed
    if app.environment != .testing,
       let adminEmail = Environment.get("ADMIN_EMAIL"),
       let adminPassword = Environment.get("ADMIN_PASSWORD"),
       let adminName = Environment.get("ADMIN_NAME") {
        let existing = try await User.query(on: app.db)
            .filter(\.$email == adminEmail.lowercased())
            .first()
        if existing == nil {
            let hash = try Bcrypt.hash(adminPassword)
            let admin = User(
                email: adminEmail.lowercased(),
                passwordHash: hash,
                name: adminName,
                role: .admin
            )
            try await admin.save(on: app.db)
            app.logger.notice("Admin user seeded: \(adminEmail)")
        }
    }

    // MARK: Content — ISO 8601 dates throughout (matches API spec and iOS client)
    // Vapor 4.106+ defaults to ISO 8601; we set it explicitly so the contract is clear.
    // app.content is not exposed in Vapor 4; mutate ContentConfiguration.global directly.
    let iso8601Encoder = JSONEncoder()
    iso8601Encoder.dateEncodingStrategy = .iso8601
    let iso8601Decoder = JSONDecoder()
    iso8601Decoder.dateDecodingStrategy = .iso8601
    var contentConfig = ContentConfiguration.global
    contentConfig.use(encoder: iso8601Encoder, for: .json)
    contentConfig.use(decoder: iso8601Decoder, for: .json)
    ContentConfiguration.global = contentConfig

    // MARK: Routes
    try routes(app)
}
