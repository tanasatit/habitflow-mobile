import SwiftUI

@main
struct HabitFlowApp: App {
    @State private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .preferredColorScheme(.light)
        }
    }
}
