import SwiftUI

@MainActor
@Observable
final class TodayViewModel {
    var dashboard: DashboardResponse?
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func load(token: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            dashboard = try await api.send(.dashboard, token: token)
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = "Failed to load dashboard."
        }
    }

    func toggleHabit(_ item: TodayHabitItem, token: String) async {
        guard let idx = dashboard?.todayHabits.firstIndex(where: { $0.id == item.id }) else { return }

        // Optimistic update
        dashboard?.todayHabits[idx].completedToday.toggle()
        let nowCompleted = dashboard?.todayHabits[idx].completedToday ?? false

        do {
            if nowCompleted {
                let _: HabitLogResponse = try await api.send(.logHabit(id: item.habit.id), token: token)
            } else {
                try await api.sendVoid(.unlogHabit(id: item.habit.id), token: token)
            }
            // Reload to get accurate streak + summary counts
            await load(token: token)
        } catch {
            // Revert optimistic update on failure
            dashboard?.todayHabits[idx].completedToday.toggle()
        }
    }
}
