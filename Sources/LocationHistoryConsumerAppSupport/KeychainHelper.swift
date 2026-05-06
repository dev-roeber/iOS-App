import Foundation
#if canImport(Security)
import Security
#else
public typealias OSStatus = Int32
#endif

/// A simple helper to securely store and retrieve strings in the Keychain (iOS/macOS).
/// Falls back to a non-secure local storage on other platforms (e.g. for CLI testing on Linux).
public enum KeychainHelper {

    public enum KeychainError: Error {
        case duplicateItem
        case encodingFailed
        case unknown(OSStatus)
    }

    public static func save(key: String, value: String) throws {
        #if canImport(Security)
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, updateQuery as CFDictionary)
            if updateStatus != errSecSuccess {
                throw KeychainError.unknown(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unknown(status)
        }
        #else
        // Fallback for Linux/testing
        UserDefaults.standard.set(value, forKey: "keychain_fallback.\(key)")
        #endif
    }

    public static func get(key: String) -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            // `kCFBooleanTrue` is statically a `CFBoolean?` and on every Apple
            // platform non-nil, but force-unwrapping it is technically UB and
            // Security.framework can be sandboxed off in App Extensions.
            // `true as CFBoolean` is the documented, lifetime-safe equivalent.
            kSecReturnData as String: true as CFBoolean,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
        #else
        // Fallback for Linux/testing
        return UserDefaults.standard.string(forKey: "keychain_fallback.\(key)")
        #endif
    }

    public static func delete(key: String) {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        #else
        // Fallback for Linux/testing
        UserDefaults.standard.removeObject(forKey: "keychain_fallback.\(key)")
        #endif
    }
}
