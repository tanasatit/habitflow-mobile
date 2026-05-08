import Fluent
import SQLKit

// Prevents two logs for the same (habit, user, UTC-date) tuple.
// completed_at is stored as TIMESTAMP WITHOUT TIME ZONE in UTC, so
// ::date gives the UTC calendar date — consistent with the streak logic.
struct AddUniqueHabitLogPerDay: AsyncMigration {
    func prepare(on database: any Database) async throws {
        let sql = database as! any SQLDatabase
        try await sql.raw("""
            CREATE UNIQUE INDEX habit_log_unique_per_day
            ON habit_logs (habit_id, user_id, ((completed_at AT TIME ZONE 'UTC')::date))
            """).run()
    }

    func revert(on database: any Database) async throws {
        let sql = database as! any SQLDatabase
        try await sql.raw("DROP INDEX IF EXISTS habit_log_unique_per_day").run()
    }
}
