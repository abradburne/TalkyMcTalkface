import Foundation
import Security

/// Errors that can occur during Keychain operations
enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedData
    case unknown(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        case .unexpectedData:
            return "Unexpected data format in Keychain"
        case .unknown(let status):
            return "Keychain error: \(status)"
        }
    }
}

/// Service for securely storing sensitive data in the macOS Keychain
/// Thread-safe singleton for Keychain operations
final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()

    /// Bundle identifier used as the Keychain service name
    private let service: String

    /// Keychain account name for the HuggingFace token
    private let huggingFaceTokenAccount = "HuggingFaceToken"

    init() {
        // Use bundle identifier or fallback
        self.service = Bundle.main.bundleIdentifier ?? "com.talky.TalkyMcTalkface"
    }

    // MARK: - HuggingFace Token

    /// Save the HuggingFace API token to Keychain
    /// - Parameter token: The token to save
    /// - Throws: KeychainError if save fails
    func saveHuggingFaceToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }

        // Delete existing token first (if any)
        try? deleteHuggingFaceToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: huggingFaceTokenAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieve the HuggingFace API token from Keychain
    /// - Returns: The token if found, nil otherwise
    func getHuggingFaceToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: huggingFaceTokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    /// Delete the HuggingFace API token from Keychain
    /// - Throws: KeychainError if delete fails (except for item not found)
    func deleteHuggingFaceToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: huggingFaceTokenAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound is OK - nothing to delete
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Check if a HuggingFace token is stored
    /// - Returns: true if a token exists in Keychain
    func hasHuggingFaceToken() -> Bool {
        return getHuggingFaceToken() != nil
    }
}
