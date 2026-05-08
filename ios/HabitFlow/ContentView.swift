import SwiftUI

struct ContentView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task { await auth.tryAutoLogin() }
    }
}

struct MainTabView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        TabView {
            Text("Today")
                .tabItem { Label("Today",    systemImage: "square.grid.2x2") }
            Text("Habits")
                .tabItem { Label("Habits",   systemImage: "checklist") }
            Text("Flow")
                .tabItem { Label("Flow",     systemImage: "sparkles") }
            Text("Calendar")
                .tabItem { Label("Calendar", systemImage: "calendar") }
            Text("Profile")
                .tabItem { Label("Profile",  systemImage: "person") }
        }
        .tint(Color.hfPrimary)
    }
}

#Preview {
    ContentView()
        .environment(AuthStore())
}
