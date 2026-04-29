import SwiftUI

@main
struct CourseWatchApp: App {
    @StateObject private var viewModel = CourseWatchViewModel()

    var body: some Scene {
        MenuBarExtra("CourseWatch", systemImage: "calendar.badge.clock") {
            ContentView()
                .environmentObject(viewModel)
                .frame(width: 520, height: 620)
                .task {
                    viewModel.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
