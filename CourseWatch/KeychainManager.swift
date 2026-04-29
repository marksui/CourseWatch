import Foundation
import Security

enum KeychainError: LocalizedError {
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            return "Keychain error \(status)."
        }
    }
}

final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "CourseWatch.CanvasToken"
    private let tokenAccount = "CanvasPersonalAccessToken"
    private let calendarFeedAccount = "CanvasCalendarFeedURL"

    private init() {}

    func saveToken(_ token: String) throws {
        try saveValue(token, account: tokenAccount)
    }

    func readToken() throws -> String? {
        try readValue(account: tokenAccount)
    }

    func deleteToken() throws {
        try deleteValue(account: tokenAccount)
    }

    func saveCalendarFeedURL(_ url: String) throws {
        try saveValue(url, account: calendarFeedAccount)
    }

    func readCalendarFeedURL() throws -> String? {
        try readValue(account: calendarFeedAccount)
    }

    func deleteCalendarFeedURL() throws {
        try deleteValue(account: calendarFeedAccount)
    }

    private func saveValue(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query = baseQuery(account: account)

        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecSuccess {
            return
        }

        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(addStatus)
            }
            return
        }

        throw KeychainError.unhandledStatus(status)
    }

    private func readValue(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }

        guard let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func deleteValue(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
