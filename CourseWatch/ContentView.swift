import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: CourseWatchViewModel

    var body: some View {
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
        .background(.background)
        .sheet(isPresented: $viewModel.isShowingSettings) {
            SettingsView()
                .environmentObject(viewModel)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CourseWatch")
                    .font(.headline)
                Text(viewModel.isConfigured ? "\(viewModel.assignments.count) upcoming" : "Canvas not configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

