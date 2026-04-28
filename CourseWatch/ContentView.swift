import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: CourseWatchViewModel

    var body: some View {
        Group {
            if viewModel.isShowingSettings {
                SettingsView {
                    viewModel.isShowingSettings = false
                }
                .environmentObject(viewModel)
            } else {
                mainContent
            }
        }
        .background(.background)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if !viewModel.isConfigured {
                EmptyStateView(
                    title: "Set up Canvas",
                    message: "Add your Canvas URL and access token to start tracking coursework."
                ) {
                    viewModel.isShowingSettings = true
                }
            } else if viewModel.assignments.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No upcoming assignments",
                    message: "Refresh anytime to check Canvas for new deadlines."
                ) {
                    Task { await viewModel.refresh() }
                }
            } else {
                assignmentList
            }

            if let errorMessage = viewModel.errorMessage {
                Divider()
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CourseWatch")
                    .font(.headline)
                HStack(spacing: 6) {
                    Image(systemName: connectionIconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(connectionColor)

                    Text("\(viewModel.connectionStatus) - \(assignmentCountText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(!viewModel.isConfigured || viewModel.isLoading)
            .help("Refresh assignments")

            Button {
                viewModel.isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Quit CourseWatch")
        }
        .buttonStyle(.borderless)
        .padding(14)
    }

    private var assignmentCountText: String {
        viewModel.isConfigured ? "\(viewModel.assignments.count) upcoming" : "Canvas not configured"
    }

    private var connectionIconName: String {
        viewModel.isConnected ? "wifi" : "wifi.slash"
    }

    private var connectionColor: Color {
        if viewModel.isLoading {
            return .secondary
        }

        return viewModel.isConnected ? .green : .red
    }

    private var assignmentList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.assignments) { assignment in
                    AssignmentRowView(assignment: assignment)
                    Divider()
                }
            }
        }
    }
}
