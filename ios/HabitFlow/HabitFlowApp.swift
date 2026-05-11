import SwiftUI

@main
struct HabitFlowApp: App {
    @State private var auth = AuthStore()
    @AppStorage("appearanceMode") private var appearanceMode: String = "light"

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "dark":   return .dark
        case "system": return nil
        default:       return .light
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .preferredColorScheme(colorScheme)
        }
    }
}
