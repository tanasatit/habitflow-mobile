import SwiftUI

@MainActor
@Observable
final class HabitsViewModel {
    var habits: [HabitItem] = []
    var stats: [String: HabitStats] = [:]
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func load(token: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let loaded: [HabitItem] = try await api.send(.habits, token: token)
            habits = loaded
            await loadStats(token: token)
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = "Failed to load habits."
        }
    }

    func createHabit(name: String, category: String, description: String?, token: String) async throws {
        let created: HabitItem = try await api.send(
            .createHabit(name: name, category: category, description: description),
            token: token
        )
        habits.append(created)
        if let s = try? await api.send(Endpoint.habitStats(id: created.id), token: token) as HabitStats {
            stats[created.id] = s
        }
    }

    func deleteHabit(id: String, token: String) async {
        do {
            try await api.sendVoid(.deleteHabit(id: id), token: token)
            habits.removeAll { $0.id == id }
            stats.removeValue(forKey: id)
        } catch {}
    }

    private func loadStats(token: String) async {
        await withTaskGroup(of: (String, HabitStats?).self) { group in
            for habit in habits {
                group.addTask {
                    let s = try? await self.api.send(Endpoint.habitStats(id: habit.id), token: token) as HabitStats
                    return (habit.id, s)
                }
            }
            for await (id, s) in group {
                if let s { stats[id] = s }
            }
        }
    }
}
