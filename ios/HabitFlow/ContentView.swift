import SwiftUI

struct ContentView: View {
    @Environment(AuthStore.self) private var auth
    @State private var navigator = AppNavigator()

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task { await auth.tryAutoLogin() }
        .environment(navigator)
    }
}

struct MainTabView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppNavigator.self) private var navigator

    var body: some View {
        @Bindable var nav = navigator
        TabView(selection: $nav.selectedTab) {
            TodayView()
                .tabItem { Label("Today",    systemImage: "square.grid.2x2") }.tag(0)
            HabitsView()
                .tabItem { Label("Habits",   systemImage: "checklist") }.tag(1)
            CoachView()
                .tabItem { Label("Flow",     systemImage: "sparkles") }.tag(2)
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }.tag(3)
            ProfileView()
                .tabItem { Label("Profile",  systemImage: "person") }.tag(4)
        }
        .tint(Color.hfPrimary)
    }
}

#Preview {
    ContentView()
        .environment(AuthStore())
}
