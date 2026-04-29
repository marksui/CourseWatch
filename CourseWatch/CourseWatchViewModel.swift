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
    @Published private(set) var hiddenAssignmentCount = 0
    @Published private(set) var completedAssignmentCount = 0
    @Published private(set) var externalDeadlineCount = 0
    @Published var isShowingSettings = false

    private let userDefaults: UserDefaults
    private let keychain: KeychainManager
    private let notificationManager: NotificationManager
    private let connectionModeKey = "connectionMode"
    private let baseURLKey = "canvasBaseURL"
    private let hiddenAssignmentsKey = "hiddenAssignmentIDs"
    private let completedAssignmentsKey = "completedAssignmentIDs"
    private let cacheFileName = "assignments-cache.json"
    private let externalDeadlinesFileName = "external-deadlines.json"
    private var hiddenAssignmentIDs: Set<String>
    private var completedAssignmentIDs: Set<String>
    private var externalDeadlines: [ExternalDeadline]

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
        self.hiddenAssignmentIDs = Set(userDefaults.stringArray(forKey: hiddenAssignmentsKey) ?? [])
        self.completedAssignmentIDs = Set(userDefaults.stringArray(forKey: completedAssignmentsKey) ?? [])
        self.externalDeadlines = Self.loadExternalDeadlines(from: Self.cacheURL(fileName: externalDeadlinesFileName))
        self.hiddenAssignmentCount = hiddenAssignmentIDs.count
        self.completedAssignmentCount = completedAssignmentIDs.count
        self.externalDeadlineCount = externalDeadlines.count
        self.assignments = Self.visibleAssignments(
            syncedAssignments: Self.loadCachedAssignments(from: Self.cacheURL(fileName: cacheFileName)),
            externalDeadlines: externalDeadlines,
            hiddenAssignmentIDs: hiddenAssignmentIDs
        )
    }

    func start() {
        Task {
            await notificationManager.requestPermission()
            if isConfigured {
                await refresh()
            } else {
                await notificationManager.rescheduleNotifications(for: incompleteAssignments)
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

    func saveCanvasBaseURL(_ baseURL: String) {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = trimmedBaseURL
        hasSuccessfulConnection = false
        userDefaults.set(trimmedBaseURL, forKey: baseURLKey)
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
        hiddenAssignmentIDs.removeAll()
        completedAssignmentIDs.removeAll()
        externalDeadlines.removeAll()
        hiddenAssignmentCount = 0
        completedAssignmentCount = 0
        externalDeadlineCount = 0
        hasSuccessfulConnection = false
        userDefaults.removeObject(forKey: connectionModeKey)
        userDefaults.removeObject(forKey: baseURLKey)
        userDefaults.removeObject(forKey: hiddenAssignmentsKey)
        userDefaults.removeObject(forKey: completedAssignmentsKey)
        try? keychain.deleteToken()
        try? keychain.deleteCalendarFeedURL()
        try? FileManager.default.removeItem(at: Self.cacheURL(fileName: cacheFileName))
        try? FileManager.default.removeItem(at: Self.cacheURL(fileName: externalDeadlinesFileName))
    }

    func hideAssignment(_ assignment: Assignment) {
        if assignment.isExternalDeadline {
            deleteExternalDeadline(assignment)
            return
        }

        hiddenAssignmentIDs.insert(assignment.localIdentifier)
        completedAssignmentIDs.remove(assignment.localIdentifier)
        persistHiddenAssignments()
        persistCompletedAssignments()
        assignments.removeAll { $0.localIdentifier == assignment.localIdentifier }

        Task {
            await notificationManager.rescheduleNotifications(for: incompleteAssignments)
        }
    }

    func addExternalDeadline(title: String, courseName: String, dueAt: Date, urlString: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "External deadline needs a title."
            return false
        }

        let trimmedCourseName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = Self.normalizedOptionalURL(from: trimmedURLString)

        if !trimmedURLString.isEmpty && url == nil {
            errorMessage = "External deadline link is not a valid URL."
            return false
        }

        let deadline = ExternalDeadline(
            id: Self.newExternalDeadlineID(existingIDs: Set(externalDeadlines.map(\.id))),
            title: trimmedTitle,
            courseName: trimmedCourseName.nilIfEmpty ?? "External deadline",
            dueAt: dueAt,
            url: url,
            createdAt: Date()
        )

        externalDeadlines.append(deadline)
        persistExternalDeadlines()
        assignments = (assignments + [deadline.assignment]).sortedByDueDate()
        errorMessage = nil

        Task {
            await notificationManager.rescheduleNotifications(for: incompleteAssignments)
        }

        return true
    }

    func isAssignmentCompleted(_ assignment: Assignment) -> Bool {
        completedAssignmentIDs.contains(assignment.localIdentifier)
    }

    func toggleAssignmentCompleted(_ assignment: Assignment) {
        if completedAssignmentIDs.contains(assignment.localIdentifier) {
            completedAssignmentIDs.remove(assignment.localIdentifier)
        } else {
            completedAssignmentIDs.insert(assignment.localIdentifier)
        }

        persistCompletedAssignments()

        Task {
            await notificationManager.rescheduleNotifications(for: incompleteAssignments)
        }
    }

    func resetCompletedAssignments() {
        completedAssignmentIDs.removeAll()
        persistCompletedAssignments()

        Task {
            await notificationManager.rescheduleNotifications(for: assignments)
        }
    }

    func restoreHiddenAssignments() {
        hiddenAssignmentIDs.removeAll()
        persistHiddenAssignments()
        assignments = Self.visibleAssignments(
            syncedAssignments: Self.loadCachedAssignments(from: Self.cacheURL(fileName: cacheFileName)),
            externalDeadlines: externalDeadlines,
            hiddenAssignmentIDs: hiddenAssignmentIDs
        )

        Task {
            await refresh()
        }
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

            let sortedAssignments = latestAssignments.sortedByDueDate()
            try saveCache(sortedAssignments)
            assignments = Self.visibleAssignments(
                syncedAssignments: sortedAssignments,
                externalDeadlines: externalDeadlines,
                hiddenAssignmentIDs: hiddenAssignmentIDs
            )
            hasSuccessfulConnection = true
            await notificationManager.rescheduleNotifications(for: incompleteAssignments)
        } catch {
            hasSuccessfulConnection = false
            if assignments.isEmpty {
                assignments = Self.visibleAssignments(
                    syncedAssignments: Self.loadCachedAssignments(from: Self.cacheURL(fileName: cacheFileName)),
                    externalDeadlines: externalDeadlines,
                    hiddenAssignmentIDs: hiddenAssignmentIDs
                )
            }

            let cacheSuffix = assignments.isEmpty ? "" : " Showing cached assignments."
            errorMessage = "\(error.localizedDescription)\(cacheSuffix)"
            await notificationManager.rescheduleNotifications(for: incompleteAssignments)
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

    private func persistHiddenAssignments() {
        hiddenAssignmentCount = hiddenAssignmentIDs.count
        userDefaults.set(Array(hiddenAssignmentIDs), forKey: hiddenAssignmentsKey)
    }

    private func persistCompletedAssignments() {
        completedAssignmentCount = completedAssignmentIDs.count
        userDefaults.set(Array(completedAssignmentIDs), forKey: completedAssignmentsKey)
    }

    private func persistExternalDeadlines() {
        externalDeadlineCount = externalDeadlines.count
        let url = Self.cacheURL(fileName: externalDeadlinesFileName)

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(externalDeadlines.sorted { $0.dueAt < $1.dueAt })
            try data.write(to: url, options: [.atomic])
        } catch {
            errorMessage = "Could not save external deadlines: \(error.localizedDescription)"
        }
    }

    private func deleteExternalDeadline(_ assignment: Assignment) {
        externalDeadlines.removeAll { $0.id == assignment.id }
        completedAssignmentIDs.remove(assignment.localIdentifier)
        hiddenAssignmentIDs.remove(assignment.localIdentifier)
        persistExternalDeadlines()
        persistCompletedAssignments()
        persistHiddenAssignments()
        assignments.removeAll { $0.localIdentifier == assignment.localIdentifier }

        Task {
            await notificationManager.rescheduleNotifications(for: incompleteAssignments)
        }
    }

    private var incompleteAssignments: [Assignment] {
        assignments.filter { !completedAssignmentIDs.contains($0.localIdentifier) }
    }

    private static func loadCachedAssignments(from url: URL) -> [Assignment] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return ((try? decoder.decode([Assignment].self, from: data)) ?? []).sortedByDueDate()
    }

    private static func loadExternalDeadlines(from url: URL) -> [ExternalDeadline] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return ((try? decoder.decode([ExternalDeadline].self, from: data)) ?? [])
            .sorted { $0.dueAt < $1.dueAt }
    }

    private static func visibleAssignments(
        syncedAssignments: [Assignment],
        externalDeadlines: [ExternalDeadline],
        hiddenAssignmentIDs: Set<String>
    ) -> [Assignment] {
        (syncedAssignments + externalDeadlines.map(\.assignment))
            .filter { !hiddenAssignmentIDs.contains($0.localIdentifier) }
            .sortedByDueDate()
    }

    private static func normalizedOptionalURL(from value: String) -> URL? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        let valueWithScheme = trimmedValue.contains("://") ? trimmedValue : "https://\(trimmedValue)"
        guard let components = URLComponents(string: valueWithScheme),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            return nil
        }

        return components.url
    }

    private static func newExternalDeadlineID(existingIDs: Set<Int>) -> Int {
        var candidate = Int(Date().timeIntervalSince1970 * 1000)
        while existingIDs.contains(candidate) {
            candidate += 1
        }

        return candidate
    }

    private static func cacheURL(fileName: String) -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "CourseWatch", directoryHint: .isDirectory)
        return directory.appending(path: fileName)
    }
}
