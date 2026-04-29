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

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                TextField("https://canvas.ucsd.edu", text: baseURLBinding)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    pasteCanvasLinkFromClipboard()
                                } label: {
                                    Label("Paste Canvas Link", systemImage: "link")
                                }
                                .help("Paste Canvas link from clipboard")
                            }

                            HStack(spacing: 8) {
                                Button {
                                    openCanvasSettings()
                                } label: {
                                    Label("Get Canvas token", systemImage: "key")
                                }
                                .disabled(canvasSettingsURL == nil)

                                Text(canvasSettingsURL == nil ? "Paste your Canvas link first." : "Opens Account > Settings where Canvas creates tokens.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }

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

                    adminTokenNotice

                    openSourceStatement

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(statusColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

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
                        normalizeBaseURL()
                        let success = await viewModel.testConnection(baseURL: baseURL, token: token)
                        statusMessage = success ? "Connection successful." : viewModel.errorMessage
                    }
                }
                .disabled(!canUseCanvasActions || viewModel.isLoading)

                Button("Save") {
                    normalizeBaseURL()
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

    private var adminTokenNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("If Canvas blocks token creation", systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.semibold))

            Text("Some schools disable personal access tokens. If Canvas says your administrators limit token creation, CourseWatch v1.0.0 cannot connect until your Canvas administrator generates an access token for you.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                copyAdminTokenRequest()
            } label: {
                Label("Copy Admin Request", systemImage: "doc.on.doc")
            }
        }
        .padding(10)
        .background(.yellow.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        normalizedCanvasBaseURL(from: baseURL) != nil &&
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var statusColor: Color {
        switch statusMessage {
        case "Admin request copied.", "Canvas link pasted.", "Connection successful.", "Token pasted.", "Token deleted.":
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
        normalizedCanvasBaseURL(from: baseURL)?
            .appending(path: "profile/settings")
    }

    private func pasteCanvasLinkFromClipboard() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string) else {
            statusMessage = "Clipboard does not contain a Canvas link."
            return
        }

        guard let normalizedURL = normalizedCanvasBaseURL(from: clipboardText) else {
            statusMessage = "Clipboard does not contain a valid Canvas link."
            return
        }

        baseURL = normalizedURL.absoluteString
        statusMessage = "Canvas link pasted."
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

    private func copyAdminTokenRequest() {
        let canvasHost = normalizedCanvasBaseURL(from: baseURL)?.host ?? "my Canvas instance"
        let request = """
        Hello,

        I am using CourseWatch, a local macOS menu bar app that reads my Canvas courses and upcoming assignments through the Canvas API. Canvas says students cannot generate their own access tokens on \(canvasHost).

        Could you generate a Canvas API access token for my account, or let me know the approved way to connect a local coursework deadline app to Canvas?

        Thank you.
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(request, forType: .string)
        statusMessage = "Admin request copied."
    }

    private func normalizeBaseURL() {
        guard let normalizedURL = normalizedCanvasBaseURL(from: baseURL) else {
            return
        }

        baseURL = normalizedURL.absoluteString
    }

    private func normalizedCanvasBaseURL(from value: String) -> URL? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        let valueWithScheme = trimmedValue.contains("://") ? trimmedValue : "https://\(trimmedValue)"
        guard let components = URLComponents(string: valueWithScheme),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host else {
            return nil
        }

        var rootComponents = URLComponents()
        rootComponents.scheme = scheme
        rootComponents.host = host
        rootComponents.port = components.port
        return rootComponents.url
    }

    private func closeSettings() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
