import Foundation
import Security

final class TracePrivacySecretStore: @unchecked Sendable {
    private let service = "app.transcripted.autocomplete.trace"
    private let account = "install-hmac-secret-v1"

    func secret() -> Data {
        if let existing = readSecret() {
            return existing
        }

        let generated = generateSecret()
        saveSecret(generated)
        return readSecret() ?? generated
    }

    private func readSecret() -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    private func saveSecret(_ secret: Data) {
        var query = baseQuery()
        query[kSecValueData as String] = secret
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery = baseQuery()
            let attributes = [kSecValueData as String: secret]
            SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func generateSecret() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return Data(bytes)
        }

        return Data(UUID().uuidString.utf8)
    }
}
