import SwiftUI

struct ProfileView: View {
    @Environment(AuthStore.self) private var auth
    @AppStorage("appearanceMode") private var appearanceMode: String = "light"
    @State private var showLogoutConfirm = false
    @State private var showAppearancePicker = false
    @State private var dashboard: DashboardResponse?

    private var user: User? { auth.user }
    private var initial: String { String(user?.name.prefix(1).uppercased() ?? "?") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                Text("Profile.")
                    .font(.hfDisplay)
                    .foregroundStyle(Color.hfOnBackground)
                    .padding(.top, HFSpacing.s4)

                // Avatar card
                avatarCard
                    .padding(.top, HFSpacing.s5)

                // Stats row
                statsRow
                    .padding(.top, HFSpacing.s4)

                // Settings
                settingsSection
                    .padding(.top, HFSpacing.s6)

                // Log out
                logoutButton
                    .padding(.top, HFSpacing.s5)
            }
            .padding(.horizontal, HFSpacing.s5)
            .padding(.bottom, HFSpacing.s8)
        }
        .background(Color.hfBackground)
        .task { await loadDashboard() }
        .confirmationDialog("Log out of HabitFlow?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) { auth.logout() }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Avatar card

    private var avatarCard: some View {
        HFCard {
            VStack(spacing: HFSpacing.s3) {
                // Initials circle
                ZStack {
                    Circle()
                        .fill(Color.hfPrimary.opacity(0.1))
                        .overlay(Circle().stroke(Color.hfPrimary, lineWidth: 2))
                        .frame(width: 72, height: 72)
                    Text(initial)
                        .font(Font.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.hfPrimary)
                }

                // Name + email
                VStack(spacing: HFSpacing.s1) {
                    Text(user?.name ?? "")
                        .font(.hfH3)
                        .foregroundStyle(Color.hfOnBackground)
                    Text(user?.email ?? "")
                        .font(.hfBodySmall)
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                }

                // Role badge
                roleBadge
            }
            .frame(maxWidth: .infinity)
            .padding(HFSpacing.s5)
        }
    }

    private var roleBadge: some View {
        let role = user?.role ?? .free
        let (bg, label): (Color, String) = switch role {
        case .admin:   (.hfOnBackground, "Admin")
        case .premium: (.hfTertiary,     "Premium")
        case .free:    (.hfSurfaceVariant, "Free")
        }
        let fg: Color = role == .free ? .hfOnSurfaceVariant : .white

        return Text(label.uppercased())
            .font(.hfLabelStrong)
            .foregroundStyle(fg)
            .padding(.horizontal, HFSpacing.s3)
            .padding(.vertical, HFSpacing.s1)
            .background(bg)
            .clipShape(Capsule())
    }

    // MARK: - Stats row

    private var statsRow: some View {
        let streak = dashboard.map { "\($0.overallStreak)" } ?? "–"
        let summary = dashboard?.habitsSummary
        let completion = summary.map { "\($0.completedToday)/\($0.active)" } ?? "–"
        let habits = summary.map { "\($0.active)" } ?? "–"

        return HStack(spacing: HFSpacing.s3) {
            ProfileStatCard(value: streak,     label: "day streak",  color: .hfPrimary,      icon: "flame.fill")
            ProfileStatCard(value: completion, label: "today",        color: .hfTertiary,     icon: "checkmark.circle.fill")
            ProfileStatCard(value: habits,     label: "habits",       color: .hfOnBackground, icon: "checklist")
        }
    }

    // MARK: - Helpers

    private func loadDashboard() async {
        dashboard = try? await APIClient.shared.send(.dashboard, token: auth.token ?? "")
    }

    // MARK: - Settings section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: HFSpacing.s2) {
            Text("SETTINGS")
                .font(.hfTiny)
                .fontWeight(.medium)
                .foregroundStyle(Color.hfOnSurfaceVariant)
                .padding(.leading, HFSpacing.s1)

            HFCard {
                VStack(spacing: 0) {
                    SettingRow(icon: "bell",          label: "Notifications",   isLast: false)
                    Button { showAppearancePicker = true } label: {
                        SettingRow(icon: "sun.max", label: "Appearance",
                                   value: appearanceMode.capitalized, isLast: false)
                    }
                    .buttonStyle(.plain)
                    SettingRow(icon: "clock",          label: "Reminder time",   value: "9:00 PM", isLast: false)
                    SettingRow(icon: "questionmark.circle", label: "Help & feedback", isLast: true)
                }
            }
            .confirmationDialog("Appearance", isPresented: $showAppearancePicker) {
                Button("Light")  { appearanceMode = "light" }
                Button("System") { appearanceMode = "system" }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    // MARK: - Log out button

    private var logoutButton: some View {
        Button { showLogoutConfirm = true } label: {
            HStack(spacing: HFSpacing.s2) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15))
                Text("Log Out")
                    .font(Font.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.hfDanger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.hfBackground)
            .clipShape(RoundedRectangle(cornerRadius: HFRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: HFRadius.md, style: .continuous)
                    .stroke(Color.hfOutline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat card

struct ProfileStatCard: View {
    let value: String
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        HFCard {
            VStack(spacing: HFSpacing.s1) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.hfNumericMedium)
                    .foregroundStyle(color)
                Text(label)
                    .font(.hfTiny)
                    .foregroundStyle(Color.hfOnSurfaceVariant)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HFSpacing.s3)
        }
    }
}

// MARK: - Setting row

struct SettingRow: View {
    let icon: String
    let label: String
    var value: String? = nil
    let isLast: Bool

    var body: some View {
        HStack(spacing: HFSpacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.hfOnBackground)
                .frame(width: 20)

            Text(label)
                .font(Font.system(size: 14, weight: .medium))
                .foregroundStyle(Color.hfOnBackground)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let value {
                Text(value)
                    .font(.hfBodySmall)
                    .foregroundStyle(Color.hfOnSurfaceVariant)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.hfOnSurfaceVariant)
        }
        .padding(.horizontal, HFSpacing.s4)
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            if !isLast { Divider().padding(.leading, HFSpacing.s4 + 20 + HFSpacing.s3) }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthStore())
}
