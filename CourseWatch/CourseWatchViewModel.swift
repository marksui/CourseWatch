import Foundation

@MainActor
final class CourseWatchViewModel: ObservableObject {
    @Published var baseURL: String
    @Published var token: String
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var assignments: [Assignment] = []
    @Published var isShowingSettings = false

    private let userDefaults: UserDefaults
    private let keychain: KeychainManager
    private let notificationManager: NotificationManager
    private let baseURLKey = "canvasBaseURL"
    private let cacheFileName = "assignments-cache.json"

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        userDefaults: UserDefaults = .standard,
        keychain: KeychainManager = .shared,
        notificationManager: NotificationManager = .shared
    ) {
        self.userDefaults = userDefaults
        self.keychain = keychain
        self.notificationManager = notificationManager
        self.baseURL = userDefaults.string(forKey: baseURLKey) ?? ""
        self.token = (try? keychain.readToken()) ?? ""
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
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        self.baseURL = trimmedBaseURL
        self.token = trimmedToken
        userDefaults.set(trimmedBaseURL, forKey: baseURLKey)

        do {
            if trimmedToken.isEmpty {
                try keychain.deleteToken()
            } else {
                try keychain.saveToken(trimmedToken)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearSettings() {
        baseURL = ""
        token = ""
        assignments = []
        userDefaults.removeObject(forKey: baseURLKey)
        try? keychain.deleteToken()
        try? FileManager.default.removeItem(at: Self.cacheURL(fileName: cacheFileName))
    }

    func testConnection(baseURL: String, token: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let client = try CanvasAPIClient(baseURLString: baseURL, token: token)
            try await client.testConnection()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refresh() async {
        guard isConfigured else {
            errorMessage = "Missing configuration. Add your Canvas URL and access token."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let client = try CanvasAPIClient(baseURLString: baseURL, token: token)
            let latestAssignments = try await client.fetchUpcomingAssignments()
            assignments = latestAssignments.sortedByDueDate()
            try saveCache(assignments)
            await notificationManager.rescheduleNotifications(for: assignments)
        } catch {
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

