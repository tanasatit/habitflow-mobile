import SwiftUI

struct TodayView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppNavigator.self) private var navigator
    @State private var vm = TodayViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let dash = vm.dashboard {
                    content(dash)
                } else if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let error = vm.error {
                    HFErrorBanner(message: error)
                        .padding(HFSpacing.s5)
                }
            }
        }
        .background(Color.hfBackground)
        .task { await vm.load(token: auth.token ?? "") }
        .refreshable { await vm.load(token: auth.token ?? "") }
    }

    @ViewBuilder
    private func content(_ dash: DashboardResponse) -> some View {
        let completed = dash.habitsSummary.completedToday
        let total = dash.habitsSummary.total

        VStack(alignment: .leading, spacing: 0) {
            // Header
            Group {
                Text("Welcome back, ")
                    .foregroundStyle(Color.hfOnBackground) +
                Text(dash.user.name)
                    .foregroundStyle(Color.hfPrimary) +
                Text("!")
                    .foregroundStyle(Color.hfOnBackground)
            }
            .font(.hfH2)
            .padding(.top, HFSpacing.s4)

            Text("\(completed) of \(total) habits done today")
                .font(.hfBodySmall)
                .foregroundStyle(Color.hfOnSurfaceVariant)
                .padding(.top, HFSpacing.s1)

            // Streak + progress row
            HStack(spacing: HFSpacing.s3) {
                streakCard(dash.overallStreak)
                progressCard(completed: completed, total: total)
            }
            .padding(.top, HFSpacing.s5)

            // Today's Rituals
            HFSectionHeader(title: "Today's Habits", actionTitle: "View all") { navigator.selectedTab = 1 }
                .padding(.top, HFSpacing.s6)
                .padding(.bottom, HFSpacing.s3)

            if dash.todayHabits.isEmpty {
                emptyState
            } else {
                ForEach(dash.todayHabits) { item in
                    HabitRowView(item: item) {
                        Task { await vm.toggleHabit(item, token: auth.token ?? "") }
                    }
                    .padding(.bottom, HFSpacing.s2)
                }
            }

            // AI Insight card
            aiInsightCard
                .padding(.top, HFSpacing.s4)
        }
        .padding(.horizontal, HFSpacing.s5)
        .padding(.bottom, HFSpacing.s8)
    }

    // MARK: - Streak card
    private func streakCard(_ streak: Int) -> some View {
        HFCard {
            VStack(spacing: HFSpacing.s1) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.hfPrimary)
                    .pulsingFlame()
                Text("\(streak)")
                    .font(.hfNumericLarge)
                    .foregroundStyle(Color.hfPrimary)
                Text("day streak")
                    .font(.hfTiny)
                    .foregroundStyle(Color.hfOnSurfaceVariant)
            }
            .frame(width: 120)
            .padding(.vertical, HFSpacing.s4)
        }
    }

    // MARK: - Progress card
    private func progressCard(completed: Int, total: Int) -> some View {
        HFCard {
            VStack(alignment: .leading, spacing: HFSpacing.s3) {
                Text("Progress")
                    .font(Font.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.hfOnBackground)

                HStack(spacing: 0) {
                    Spacer()
                    HFProgressRing(
                        color: .hfTertiary,
                        progress: total > 0 ? Double(completed) / Double(total) : 0,
                        label: "Daily",
                        valueText: "\(completed)/\(total)"
                    )
                    Spacer()
                }
            }
            .padding(HFSpacing.s4)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: HFSpacing.s3) {
            Image(systemName: "checklist")
                .font(.system(size: 36))
                .foregroundStyle(Color.hfOutline)
            Text("No habits yet.")
                .font(.hfH3)
                .foregroundStyle(Color.hfOnSurfaceVariant)
            Text("Create your first habit to start building better routines.")
                .font(.hfBody)
                .foregroundStyle(Color.hfOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HFSpacing.s10)
    }

    // MARK: - AI Insight card
    private var aiInsightCard: some View {
        VStack(alignment: .leading, spacing: HFSpacing.s2) {
            HStack(spacing: HFSpacing.s2) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.hfOnBackground)
                Text("AI Insight")
                    .font(Font.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.hfOnBackground)
            }
            Text("You're building great momentum! Keep up your consistency and your streak will grow even stronger.")
                .font(.hfBody)
                .foregroundStyle(Color.hfOnBackground)
                .lineSpacing(3)
        }
        .padding(HFSpacing.s4)
        .background(Color.hfAccent)
        .clipShape(RoundedRectangle(cornerRadius: HFRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HFRadius.xl, style: .continuous)
                .stroke(Color.hfOutline, lineWidth: 1)
        )
    }
}

#Preview {
    TodayView()
        .environment(AuthStore())
}
