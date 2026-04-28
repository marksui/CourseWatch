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
    private let account = "CanvasPersonalAccessToken"

    private init() {}

    func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        let query = baseQuery()

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

    func readToken() throws -> String? {
        var query = baseQuery()
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

    func deleteToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

