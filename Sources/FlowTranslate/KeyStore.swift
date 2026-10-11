import Foundation
import Security

/// Keeps credentials in Keychain. UserDefaults contains only an account locator.
/// A legacy item's partition ACL can retain an older ad-hoc signature even after
/// Allow/Always Allow. After explicit unlock, create a private item as this app,
/// verify a noninteractive read, then publish its locator. Never loosen an ACL.
final class KeychainCredentialStore {
    private static let interactionLock = NSRecursiveLock()
    private let service: String
    private let defaults: UserDefaults
    private let locatorKey = "keychainCredentialAccount"
    private let managedPrefix = "translation.authorized."
    private let legacyAccount = "translation"

    init(service: String, defaults: UserDefaults) {
        self.service = service; self.defaults = defaults
    }

    private var account: String {
        guard let value = defaults.string(forKey: locatorKey), value.hasPrefix(managedPrefix) else { return legacyAccount }
        return value
    }
    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    private func withInteraction<T>(_ allowed: Bool, unavailable: T, _ operation: () -> T) -> T {
        Self.interactionLock.lock()
        defer { Self.interactionLock.unlock() }
        var previous: DarwinBoolean = true
        guard SecKeychainGetUserInteractionAllowed(&previous) == errSecSuccess,
              SecKeychainSetUserInteractionAllowed(allowed) == errSecSuccess else { return unavailable }
        defer { SecKeychainSetUserInteractionAllowed(previous.boolValue) }
        return operation()
    }
    private func readAccount(_ account: String, allowUI: Bool) -> (value: String?, status: OSStatus) {
        withInteraction(allowUI, unavailable: (nil, errSecInteractionNotAllowed)) {
            var q = query(account)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            q[kSecUseAuthenticationUI as String] = allowUI ? kSecUseAuthenticationUIAllow : kSecUseAuthenticationUIFail
            var item: CFTypeRef?
            let status = SecItemCopyMatching(q as CFDictionary, &item)
            guard status == errSecSuccess, let data = item as? Data,
                  let value = String(data: data, encoding: .utf8) else { return (nil, status == errSecSuccess ? errSecDecode : status) }
            return (value, status)
        }
    }
    private func deleteManagedAccount(_ account: String) -> OSStatus {
        guard account.hasPrefix(managedPrefix) else { return errSecParam }
        return withInteraction(false, unavailable: errSecInteractionNotAllowed) {
            var q = query(account)
            q[kSecReturnRef as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            let status = SecItemCopyMatching(q as CFDictionary, &item)
            guard status == errSecSuccess, let item else { return status }
            // This store uses the file-based login keychain. Its legacy delete
            // API removes the exact reference, including items from an older
            // build; SecItemDelete can instead reject its stale owner ACL.
            return SecKeychainItemDelete(item as! SecKeychainItem)
        }
    }
    func readResult(allowUI: Bool) -> (value: String?, status: OSStatus) {
        Self.interactionLock.lock(); defer { Self.interactionLock.unlock() }
        let selected = account
        let result = readAccount(selected, allowUI: allowUI)
        // The legacy item is retained for rollback; only fall back for a missing
        // locator, never for a denied read of a newer credential.
        if result.status == errSecItemNotFound, selected != legacyAccount {
            return readAccount(legacyAccount, allowUI: allowUI)
        }
        return result
    }
    func unlock() -> (value: String?, status: OSStatus, persistenceStatus: OSStatus) {
        Self.interactionLock.lock(); defer { Self.interactionLock.unlock() }
        let result = readResult(allowUI: true)
        guard let value = result.value else { return (nil, result.status, result.status) }
        // A successful interactive read can be cached for this process while
        // the item's partition still names the previous build. Always renew
        // after explicit unlock rather than trusting that process-local grant.
        let persistence = write(value, renewAccess: true)
        return (value, result.status, persistence)
    }
    func write(_ value: String, renewAccess: Bool = false) -> OSStatus {
        guard !value.isEmpty else { return errSecParam }
        Self.interactionLock.lock(); defer { Self.interactionLock.unlock() }
        let current = readResult(allowUI: false)
        if !renewAccess, current.status == errSecSuccess, current.value == value { return errSecSuccess }
        let previous = account, candidate = managedPrefix + UUID().uuidString
        let status: OSStatus = withInteraction(false, unavailable: errSecInteractionNotAllowed) {
            var app: SecTrustedApplication?, access: SecAccess?
            var result = SecTrustedApplicationCreateFromPath(nil, &app)
            guard result == errSecSuccess, let app else { return result }
            result = SecAccessCreate("Flow Translate API Key" as CFString, [app] as CFArray, &access)
            guard result == errSecSuccess, let access else { return result }
            var q = query(candidate)
            q[kSecValueData as String] = Data(value.utf8)
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            q[kSecAttrAccess as String] = access
            q[kSecAttrLabel as String] = "Flow Translate API Key"
            return SecItemAdd(q as CFDictionary, nil)
        }
        guard status == errSecSuccess else { return status }
        let verified = readAccount(candidate, allowUI: false)
        guard verified.status == errSecSuccess, verified.value == value else {
            _ = deleteManagedAccount(candidate)
            return verified.status == errSecSuccess ? errSecDecode : verified.status
        }
        defaults.set(candidate, forKey: locatorKey)
        // Keep the original legacy item as a rollback copy. Superseded managed
        // items can be removed only after the new item has passed read-back.
        if previous.hasPrefix(managedPrefix) {
            _ = deleteManagedAccount(previous)
        }
        return errSecSuccess
    }
}

enum KeyStore {
    private static let store = KeychainCredentialStore(service: "io.github.xyizhan.FlowTranslate.api", defaults: .standard)
    static func read() -> String? { readResult(allowUI: false).value }
    static func readResult(allowUI: Bool) -> (value: String?, status: OSStatus) { store.readResult(allowUI: allowUI) }
    static func unlock() -> (value: String?, status: OSStatus, persistenceStatus: OSStatus) { store.unlock() }
    static func write(_ value: String) -> OSStatus { store.write(value) }
}
