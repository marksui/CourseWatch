import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CourseWatchViewModel

    @State private var baseURL: String = ""
    @State private var token: String = ""
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.title2.weight(.semibold))
                    Text("Connect CourseWatch to Canvas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close settings")
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("https://canvas.ucsd.edu", text: $baseURL)
                    .textFieldStyle(.roundedBorder)

                SecureField("Personal access token", text: $token)
                    .textFieldStyle(.roundedBorder)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(statusMessage == "Connection successful." ? .green : .red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack {
                Button("Delete Token", role: .destructive) {
                    token = ""
                    viewModel.saveSettings(baseURL: baseURL, token: "")
                    statusMessage = "Token deleted."
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Test Connection") {
                    Task {
                        let success = await viewModel.testConnection(baseURL: baseURL, token: token)
                        statusMessage = success ? "Connection successful." : viewModel.errorMessage
                    }
                }
                .disabled(baseURL.isEmpty || token.isEmpty || viewModel.isLoading)

                Button("Save") {
                    viewModel.saveSettings(baseURL: baseURL, token: token)
                    Task { await viewModel.refresh() }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(baseURL.isEmpty || token.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 460, height: 280)
        .onAppear {
            baseURL = viewModel.baseURL
            token = viewModel.token
        }
    }
}
