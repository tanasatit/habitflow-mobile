import Fluent
import SQLKit

// Prevents two logs for the same (habit, user, UTC-date) tuple.
// completed_at is stored as TIMESTAMP WITHOUT TIME ZONE in UTC, so
// ::date gives the UTC calendar date — consistent with the streak logic.
struct AddUniqueHabitLogPerDay: AsyncMigration {
    func prepare(on database: any Database) async throws {
        let sql = database as! any SQLDatabase
        // timestamptz::date is STABLE not IMMUTABLE, so Postgres rejects it in an index.
        // Wrapping in an IMMUTABLE function is the standard workaround.
        try await sql.raw("""
            CREATE OR REPLACE FUNCTION hf_utc_date(timestamptz)
            RETURNS date LANGUAGE sql IMMUTABLE STRICT
            AS $$ SELECT ($1 AT TIME ZONE 'UTC')::date $$
            """).run()
        try await sql.raw("""
            CREATE UNIQUE INDEX habit_log_unique_per_day
            ON habit_logs (habit_id, user_id, hf_utc_date(completed_at))
            """).run()
    }

    func revert(on database: any Database) async throws {
        let sql = database as! any SQLDatabase
        try await sql.raw("DROP INDEX IF EXISTS habit_log_unique_per_day").run()
        try await sql.raw("DROP FUNCTION IF EXISTS hf_utc_date(timestamptz)").run()
    }
}
