import SwiftUI

@main
struct CourseWatchApp: App {
    @StateObject private var viewModel = CourseWatchViewModel()

    var body: some Scene {
        MenuBarExtra("CourseWatch", systemImage: "calendar.badge.clock") {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(viewModel.appearance.colorScheme)
                .frame(width: 520, height: 620)
                .task {
                    viewModel.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}

private extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
