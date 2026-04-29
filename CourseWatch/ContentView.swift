import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: CourseWatchViewModel
    @State private var isShowingExternalDeadlineEditor = false

    var body: some View {
        Group {
            if isShowingExternalDeadlineEditor {
                ExternalDeadlineEditorView {
                    isShowingExternalDeadlineEditor = false
                }
                .environmentObject(viewModel)
            } else if viewModel.isShowingSettings {
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

            if viewModel.assignments.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: viewModel.isConfigured ? "No upcoming assignments" : "No deadlines yet",
                    message: viewModel.isConfigured
                        ? "Refresh anytime to check Canvas, or add an external deadline."
                        : "Add an external deadline, or connect Canvas in Settings.",
                    primaryButtonTitle: "Add Deadline",
                    secondaryButtonTitle: viewModel.isConfigured ? "Refresh" : "Settings",
                    primaryAction: {
                        isShowingExternalDeadlineEditor = true
                    },
                    secondaryAction: {
                        if viewModel.isConfigured {
                            Task { await viewModel.refresh() }
                        } else {
                            viewModel.isShowingSettings = true
                        }
                    }
                )
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
                isShowingExternalDeadlineEditor = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Add external deadline")

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
        if viewModel.isConfigured {
            return "\(viewModel.assignments.count) upcoming"
        }

        return viewModel.assignments.isEmpty ? "Canvas not configured" : "\(viewModel.assignments.count) local"
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
                    AssignmentRowView(
                        assignment: assignment,
                        isCompleted: viewModel.isAssignmentCompleted(assignment),
                        onToggleCompleted: {
                            viewModel.toggleAssignmentCompleted(assignment)
                        },
                        onDelete: {
                            viewModel.hideAssignment(assignment)
                        }
                    )
                    Divider()
                }
            }
        }
    }
}

private struct ExternalDeadlineEditorView: View {
    @EnvironmentObject private var viewModel: CourseWatchViewModel

    let onClose: () -> Void

    @State private var title = ""
    @State private var courseName = ""
    @State private var dueAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var link = ""
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("External Deadline")
                        .font(.title2.weight(.semibold))
                    Text("Add a local deadline outside Canvas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("Deadline title", text: $title)
                    .textFieldStyle(.roundedBorder)

                TextField("Course or source", text: $courseName)
                    .textFieldStyle(.roundedBorder)

                DatePicker("Due", selection: $dueAt, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)

                TextField("Optional link", text: $link)
                    .textFieldStyle(.roundedBorder)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack {
                Label("Stored locally", systemImage: "internaldrive")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveDeadline()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
    }

    private func saveDeadline() {
        if viewModel.addExternalDeadline(
            title: title,
            courseName: courseName,
            dueAt: dueAt,
            urlString: link
        ) {
            onClose()
        } else {
            statusMessage = viewModel.errorMessage
        }
    }
}
