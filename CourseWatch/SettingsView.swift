import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CourseWatchViewModel

    let onClose: (() -> Void)?

    @State private var connectionMode: ConnectionMode = .canvasAPI
    @State private var baseURL: String = ""
    @State private var token: String = ""
    @State private var calendarFeedURL: String = ""
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
                    Picker("Connection", selection: $connectionMode) {
                        ForEach(ConnectionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

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
                                    if connectionMode == .canvasAPI {
                                        openCanvasSettings()
                                    } else {
                                        openCanvasCalendar()
                                    }
                                } label: {
                                    Label(connectionMode == .canvasAPI ? "Get Canvas token" : "Open Canvas Calendar", systemImage: connectionMode == .canvasAPI ? "key" : "calendar")
                                }
                                .disabled(canvasSettingsURL == nil)

                                Text(canvasURLHelpText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        if connectionMode == .canvasAPI {
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
                        } else {
                            calendarFeedFields
                        }
                    }

                    if connectionMode == .canvasAPI {
                        tokenHelp

                        adminTokenNotice
                    } else {
                        calendarFeedHelp
                    }

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
                Button(connectionMode == .canvasAPI ? "Delete Token" : "Delete Feed", role: .destructive) {
                    let nextToken = connectionMode == .canvasAPI ? "" : token
                    let nextCalendarFeedURL = connectionMode == .calendarFeed ? "" : calendarFeedURL
                    token = nextToken
                    calendarFeedURL = nextCalendarFeedURL
                    viewModel.saveSettings(
                        connectionMode: connectionMode,
                        baseURL: baseURL,
                        token: nextToken,
                        calendarFeedURL: nextCalendarFeedURL
                    )
                    statusMessage = connectionMode == .canvasAPI ? "Token deleted." : "Calendar feed deleted."
                }

                Spacer()

                Button("Cancel") {
                    closeSettings()
                }
                .keyboardShortcut(.cancelAction)

                Button("Test Connection") {
                    Task {
                        normalizeBaseURL()
                        normalizeCalendarFeedURL()
                        let success = await viewModel.testConnection(
                            connectionMode: connectionMode,
                            baseURL: baseURL,
                            token: token,
                            calendarFeedURL: calendarFeedURL
                        )
                        statusMessage = success ? "Connection successful." : viewModel.errorMessage
                    }
                }
                .disabled(!canUseCurrentMode || viewModel.isLoading)

                Button("Save") {
                    normalizeBaseURL()
                    normalizeCalendarFeedURL()
                    viewModel.saveSettings(
                        connectionMode: connectionMode,
                        baseURL: baseURL,
                        token: token,
                        calendarFeedURL: calendarFeedURL
                    )
                    Task { await viewModel.refresh() }
                    closeSettings()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canUseCurrentMode)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            connectionMode = viewModel.connectionMode
            baseURL = viewModel.baseURL
            token = viewModel.token
            calendarFeedURL = viewModel.calendarFeedURL
        }
    }

    private var calendarFeedFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Canvas Calendar Feed URL (.ics or webcal://)", text: calendarFeedURLBinding)
                    .textFieldStyle(.roundedBorder)

                Button {
                    extractCalendarFeedFromClipboard()
                } label: {
                    Label("Auto Extract", systemImage: "wand.and.stars")
                }
                .help("Extract .ics or webcal link from clipboard")
            }

            Text("Copy the Canvas Calendar Feed popup text or link, then use Auto Extract.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

            Text("Some schools disable personal access tokens. If Canvas also blocks OAuth/login integrations, CourseWatch v2.0.0 needs an admin-issued token or a Canvas Calendar Feed / .ics fallback.")
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

    private var calendarFeedHelp: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Calendar Feed fallback", systemImage: "calendar.badge.clock")
                .font(.subheadline.weight(.semibold))

            Text("Use this when Canvas API tokens or OAuth are blocked. Open Canvas Calendar, click Calendar Feed, copy the feed link or the whole popup text, then use Auto Extract.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("This mode can show due dates and schedule notifications, but it may not include full course names, submission status, or every Canvas To Do item.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(.blue.opacity(0.10))
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

    private var canUseCurrentMode: Bool {
        switch connectionMode {
        case .canvasAPI:
            return normalizedCanvasBaseURL(from: baseURL) != nil &&
                !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .calendarFeed:
            return ICSCalendarClient.normalizedFeedURL(from: calendarFeedURL) != nil
        }
    }

    private var statusColor: Color {
        switch statusMessage {
        case "Admin request copied.", "Calendar feed deleted.", "Calendar feed extracted.", "Canvas link pasted.", "Connection successful.", "Token pasted.", "Token deleted.":
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

    private var calendarFeedURLBinding: Binding<String> {
        Binding(
            get: { calendarFeedURL },
            set: { setCalendarFeedURL($0) }
        )
    }

    private var canvasSettingsURL: URL? {
        normalizedCanvasBaseURL(from: baseURL)?
            .appending(path: "profile/settings")
    }

    private var canvasCalendarURL: URL? {
        normalizedCanvasBaseURL(from: baseURL)?
            .appending(path: "calendar")
    }

    private var canvasURLHelpText: String {
        if normalizedCanvasBaseURL(from: baseURL) == nil {
            return "Paste your Canvas link first."
        }

        return connectionMode == .canvasAPI
            ? "Opens Account > Settings where Canvas creates tokens."
            : "Opens Canvas Calendar so you can copy Calendar Feed."
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

    private func extractCalendarFeedFromClipboard() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string) else {
            statusMessage = "Clipboard does not contain text."
            return
        }

        guard let feedURL = ICSCalendarClient.extractFeedURL(from: clipboardText) else {
            statusMessage = "Could not find an .ics or webcal link in the clipboard."
            return
        }

        calendarFeedURL = feedURL.absoluteString
        statusMessage = "Calendar feed extracted."
    }

    private func setCalendarFeedURL(_ value: String) {
        if let feedURL = ICSCalendarClient.extractFeedURL(from: value) {
            calendarFeedURL = feedURL.absoluteString
        } else {
            calendarFeedURL = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
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

    private func openCanvasCalendar() {
        guard let canvasCalendarURL else {
            statusMessage = "Enter a valid Canvas URL first."
            return
        }

        NSWorkspace.shared.open(canvasCalendarURL)
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

    private func normalizeCalendarFeedURL() {
        guard let normalizedURL = ICSCalendarClient.normalizedFeedURL(from: calendarFeedURL) else {
            return
        }

        calendarFeedURL = normalizedURL.absoluteString
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
