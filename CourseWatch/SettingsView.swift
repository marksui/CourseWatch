import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CourseWatchViewModel

    let onClose: (() -> Void)?

    @State private var baseURL: String = ""
    @State private var token: String = ""
    @State private var statusMessage: String?
    @State private var isTokenVisible = false
    @State private var isHelpExpanded = true

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    closeSettings()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close settings")
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("https://canvas.ucsd.edu", text: baseURLBinding)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    Group {
                        if isTokenVisible {
                            TextField("Canvas access token", text: tokenBinding)
                        } else {
                            SecureField("Canvas access token", text: tokenBinding)
                        }
                    }
                    .textFieldStyle(.roundedBorder)

                    Button {
                        isTokenVisible.toggle()
                    } label: {
                        Image(systemName: isTokenVisible ? "eye.slash" : "eye")
                    }
                    .help(isTokenVisible ? "Hide token" : "Show token")

                    Button {
                        pasteTokenFromClipboard()
                    } label: {
                        Label("Paste Token", systemImage: "doc.on.clipboard")
                    }
                    .help("Paste token from clipboard")
                }
            }

            tokenHelp

            openSourceStatement

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(statusColor)
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
                    closeSettings()
                }
                .keyboardShortcut(.cancelAction)

                Button("Test Connection") {
                    Task {
                        let success = await viewModel.testConnection(baseURL: baseURL, token: token)
                        statusMessage = success ? "Connection successful." : viewModel.errorMessage
                    }
                }
                .disabled(!canUseCanvasActions || viewModel.isLoading)

                Button("Save") {
                    viewModel.saveSettings(baseURL: baseURL, token: token)
                    Task { await viewModel.refresh() }
                    closeSettings()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canUseCanvasActions)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            baseURL = viewModel.baseURL
            token = viewModel.token
        }
    }

    private var tokenHelp: some View {
        DisclosureGroup("What is a Canvas token?", isExpanded: $isHelpExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Canvas uses a personal access token instead of your password. In Canvas, go to Account > Settings > Approved Integrations > New Access Token.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Use CourseWatch as the purpose, generate the token, then copy the token value once and paste it here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    openCanvasSettings()
                } label: {
                    Label("Open Canvas Settings", systemImage: "safari")
                }
                .disabled(canvasSettingsURL == nil)
            }
            .padding(.top, 6)
        }
        .font(.subheadline.weight(.medium))
    }

    private var openSourceStatement: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Open-source security statement", systemImage: "lock.shield")
                .font(.subheadline.weight(.semibold))

            Text("This app is open source and provided as-is. Do not paste your Canvas password here. You are responsible for protecting passwords, tokens, your device, and private information.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("The maintainer is not responsible for password leaks, token leaks, personal information exposure, data loss, account issues, modified builds, compromised devices, or misuse of the app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var canUseCanvasActions: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var statusColor: Color {
        switch statusMessage {
        case "Connection successful.", "Token pasted.", "Token deleted.":
            return .green
        default:
            return .red
        }
    }

    private var baseURLBinding: Binding<String> {
        Binding(
            get: { baseURL },
            set: { baseURL = $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
    }

    private var tokenBinding: Binding<String> {
        Binding(
            get: { token },
            set: { setToken($0) }
        )
    }

    private var canvasSettingsURL: URL? {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil else {
            return nil
        }

        return url.appending(path: "profile/settings")
    }

    private func pasteTokenFromClipboard() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string) else {
            statusMessage = "Clipboard does not contain text."
            return
        }

        let cleanedToken = cleanedTokenText(clipboardText)
        guard !cleanedToken.isEmpty else {
            statusMessage = "Clipboard did not contain a token."
            return
        }

        setToken(clipboardText)
        statusMessage = cleanedToken.count > 1024
            ? "That paste looked too long. Copy only the token value from Canvas."
            : "Token pasted."
    }

    private func setToken(_ value: String) {
        let cleanedToken = cleanedTokenText(value)
        token = String(cleanedToken.prefix(1024))

        if cleanedToken.count > 1024 {
            statusMessage = "That paste looked too long. Copy only the token value from Canvas."
        }
    }

    private func cleanedTokenText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isWhitespace }
    }

    private func openCanvasSettings() {
        guard let canvasSettingsURL else {
            statusMessage = "Enter a valid Canvas URL first."
            return
        }

        NSWorkspace.shared.open(canvasSettingsURL)
    }

    private func closeSettings() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
