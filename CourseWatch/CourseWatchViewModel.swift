import Foundation

@MainActor
final class CourseWatchViewModel: ObservableObject {
    @Published var connectionMode: ConnectionMode
    @Published var baseURL: String
    @Published var token: String
    @Published var calendarFeedURL: String
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var assignments: [Assignment] = []
    @Published private(set) var hasSuccessfulConnection = false
    @Published var isShowingSettings = false

    private let userDefaults: UserDefaults
    private let keychain: KeychainManager
    private let notificationManager: NotificationManager
    private let connectionModeKey = "connectionMode"
    private let baseURLKey = "canvasBaseURL"
    private let cacheFileName = "assignments-cache.json"

    var isConfigured: Bool {
        switch connectionMode {
        case .canvasAPI:
            return !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .calendarFeed:
            return ICSCalendarClient.normalizedFeedURL(from: calendarFeedURL) != nil
        }
    }

    var connectionStatus: String {
        if !isConfigured {
            return "Not connected"
        }

        if isLoading {
            return "Checking connection"
        }

        return hasSuccessfulConnection ? "Connected via \(connectionMode.title)" : "Not connected"
    }

    var isConnected: Bool {
        isConfigured && hasSuccessfulConnection && errorMessage == nil
    }

    init(
        userDefaults: UserDefaults = .standard,
        keychain: KeychainManager = .shared,
        notificationManager: NotificationManager = .shared
    ) {
        self.userDefaults = userDefaults
        self.keychain = keychain
        self.notificationManager = notificationManager
        self.connectionMode = ConnectionMode(
            rawValue: userDefaults.string(forKey: connectionModeKey) ?? ConnectionMode.canvasAPI.rawValue
        ) ?? .canvasAPI
        self.baseURL = userDefaults.string(forKey: baseURLKey) ?? ""
        self.token = (try? keychain.readToken()) ?? ""
        self.calendarFeedURL = (try? keychain.readCalendarFeedURL()) ?? ""
        self.assignments = Self.loadCachedAssignments(from: Self.cacheURL(fileName: cacheFileName))
    }

    func start() {
        Task {
            await notificationManager.requestPermission()
            if isConfigured {
                await refresh()
            }
        }
    }

    func saveSettings(baseURL: String, token: String) {
        saveSettings(
            connectionMode: .canvasAPI,
            baseURL: baseURL,
            token: token,
            calendarFeedURL: calendarFeedURL
        )
    }

    func saveSettings(connectionMode: ConnectionMode, baseURL: String, token: String, calendarFeedURL: String) {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCalendarFeedURL = calendarFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)

        self.connectionMode = connectionMode
        self.baseURL = trimmedBaseURL
        self.token = trimmedToken
        self.calendarFeedURL = trimmedCalendarFeedURL
        hasSuccessfulConnection = false
        userDefaults.set(connectionMode.rawValue, forKey: connectionModeKey)
        userDefaults.set(trimmedBaseURL, forKey: baseURLKey)

        do {
            if trimmedToken.isEmpty {
                try keychain.deleteToken()
            } else {
                try keychain.saveToken(trimmedToken)
            }

            if trimmedCalendarFeedURL.isEmpty {
                try keychain.deleteCalendarFeedURL()
            } else {
                try keychain.saveCalendarFeedURL(trimmedCalendarFeedURL)
            }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearSettings() {
        baseURL = ""
        token = ""
        calendarFeedURL = ""
        assignments = []
        hasSuccessfulConnection = false
        userDefaults.removeObject(forKey: connectionModeKey)
        userDefaults.removeObject(forKey: baseURLKey)
        try? keychain.deleteToken()
        try? keychain.deleteCalendarFeedURL()
        try? FileManager.default.removeItem(at: Self.cacheURL(fileName: cacheFileName))
    }

    func testConnection(baseURL: String, token: String) async -> Bool {
        await testConnection(
            connectionMode: .canvasAPI,
            baseURL: baseURL,
            token: token,
            calendarFeedURL: calendarFeedURL
        )
    }

    func testConnection(
        connectionMode: ConnectionMode,
        baseURL: String,
        token: String,
        calendarFeedURL: String
    ) async -> Bool {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCalendarFeedURL = calendarFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            switch connectionMode {
            case .canvasAPI:
                let client = try CanvasAPIClient(baseURLString: trimmedBaseURL, token: trimmedToken)
                try await client.testConnection()
            case .calendarFeed:
                let client = try ICSCalendarClient(feedURLString: trimmedCalendarFeedURL)
                _ = try await client.fetchAssignments()
            }

            hasSuccessfulConnection = connectionMode == self.connectionMode &&
                trimmedBaseURL == self.baseURL &&
                trimmedToken == self.token &&
                trimmedCalendarFeedURL == self.calendarFeedURL
            return true
        } catch {
            if connectionMode == self.connectionMode &&
                trimmedBaseURL == self.baseURL &&
                trimmedToken == self.token &&
                trimmedCalendarFeedURL == self.calendarFeedURL {
                hasSuccessfulConnection = false
            }
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refresh() async {
        guard isConfigured else {
            errorMessage = "Missing configuration. Add Canvas API settings or a Calendar Feed URL."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let latestAssignments: [Assignment]
            switch connectionMode {
            case .canvasAPI:
                let client = try CanvasAPIClient(baseURLString: baseURL, token: token)
                latestAssignments = try await client.fetchUpcomingAssignments()
            case .calendarFeed:
                let client = try ICSCalendarClient(feedURLString: calendarFeedURL)
                latestAssignments = try await client.fetchAssignments()
            }

            assignments = latestAssignments.sortedByDueDate()
            try saveCache(assignments)
            hasSuccessfulConnection = true
            await notificationManager.rescheduleNotifications(for: assignments)
        } catch {
            hasSuccessfulConnection = false
            if assignments.isEmpty {
                assignments = Self.loadCachedAssignments(from: Self.cacheURL(fileName: cacheFileName))
            }

            let cacheSuffix = assignments.isEmpty ? "" : " Showing cached assignments."
            errorMessage = "\(error.localizedDescription)\(cacheSuffix)"
        }

        isLoading = false
    }

    private func saveCache(_ assignments: [Assignment]) throws {
        let url = Self.cacheURL(fileName: cacheFileName)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(assignments)
        try data.write(to: url, options: [.atomic])
    }

    private static func loadCachedAssignments(from url: URL) -> [Assignment] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return ((try? decoder.decode([Assignment].self, from: data)) ?? []).sortedByDueDate()
    }

    private static func cacheURL(fileName: String) -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "CourseWatch", directoryHint: .isDirectory)
        return directory.appending(path: fileName)
    }
}
