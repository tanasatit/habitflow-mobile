import SwiftUI

@MainActor
@Observable
final class AppNavigator {
    var selectedTab: Int = 0
    var calendarTargetDate: Date? = nil
}
