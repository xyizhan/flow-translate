#!/bin/zsh
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_TEMP="$(mktemp -d /tmp/FlowTranslate-KeychainCheck.XXXXXX)"
TASK_SUITE="io.github.xyizhan.FlowTranslate.verification.$(uuidgen)"
trap 'if [[ -x "$TASK_TEMP/check-b" ]]; then "$TASK_TEMP/check-b" "$TASK_SUITE" cleanup >/dev/null 2>&1 || true; fi; rm -rf "$TASK_TEMP"' EXIT
cat > "$TASK_TEMP/main.swift" <<'SWIFT'
import Foundation
import Security

let service = CommandLine.arguments[1], mode = CommandLine.arguments[2]
precondition(service.hasPrefix("io.github.xyizhan.FlowTranslate.verification."))
let defaults = UserDefaults(suiteName: service)!
let store = KeychainCredentialStore(service: service, defaults: defaults)
#if SECOND_BUILD
let build = "B"
#else
let build = "A"
#endif
switch mode {
case "legacy":
    SecKeychainSetUserInteractionAllowed(false)
    let q: [String:Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:service,
                          kSecAttrAccount as String:"translation", kSecValueData as String:Data("generated-fixture-A".utf8)]
    precondition(SecItemAdd(q as CFDictionary, nil) == errSecSuccess)
case "write":
    precondition(store.write("generated-fixture-A") == errSecSuccess)
    precondition(defaults.synchronize())
case "read-a":
    let result = store.readResult(allowUI: false)
    precondition(result.status == errSecSuccess && result.value == "generated-fixture-A")
case "different-build":
    let result = store.readResult(allowUI: false)
    precondition(result.value == nil && result.status != errSecSuccess)
case "renew":
    // Simulates the already-authorized credential; no real key or UI prompt.
    let oldLocator = defaults.string(forKey: "keychainCredentialAccount")
    precondition(store.write("generated-fixture-A", renewAccess: true) == errSecSuccess)
    precondition(defaults.string(forKey: "keychainCredentialAccount") != oldLocator)
    precondition(defaults.synchronize())
case "replace":
    precondition(store.write("generated-fixture-B") == errSecSuccess)
    precondition(store.write("") == errSecParam)
    precondition(defaults.synchronize())
case "read-b":
    let result = store.readResult(allowUI: false)
    precondition(result.status == errSecSuccess && result.value == "generated-fixture-B")
    var attributes: CFTypeRef?
    let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:service, kSecReturnAttributes as String:true, kSecMatchLimit as String:kSecMatchLimitAll]
    precondition(SecItemCopyMatching(query as CFDictionary, &attributes) == errSecSuccess)
    let records = attributes as! [[String:Any]]
    precondition(records.count == 2) // Retained legacy item plus one active private item.
case "cleanup":
    SecKeychainSetUserInteractionAllowed(false)
    let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:service, kSecReturnRef as String:true, kSecMatchLimit as String:kSecMatchLimitAll]
    var items: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &items)
    precondition(status == errSecSuccess || status == errSecItemNotFound)
    for item in (items as? [SecKeychainItem] ?? []) { precondition(SecKeychainItemDelete(item) == errSecSuccess) }
    precondition(SecItemCopyMatching(query as CFDictionary, &items) == errSecItemNotFound)
    defaults.removePersistentDomain(forName: service)
    defaults.synchronize()
default: fatalError("Unknown check")
}
print("KEYCHAIN PASS: build \(build), \(mode)")
SWIFT
swiftc -suppress-warnings "$TASK_ROOT/Sources/FlowTranslate/KeyStore.swift" "$TASK_TEMP/main.swift" -o "$TASK_TEMP/check-a"
swiftc -suppress-warnings -DSECOND_BUILD "$TASK_ROOT/Sources/FlowTranslate/KeyStore.swift" "$TASK_TEMP/main.swift" -o "$TASK_TEMP/check-b"
"$TASK_TEMP/check-a" "$TASK_SUITE" legacy
"$TASK_TEMP/check-a" "$TASK_SUITE" read-a
"$TASK_TEMP/check-b" "$TASK_SUITE" different-build
"$TASK_TEMP/check-b" "$TASK_SUITE" renew
"$TASK_TEMP/check-b" "$TASK_SUITE" read-a
"$TASK_TEMP/check-b" "$TASK_SUITE" replace
"$TASK_TEMP/check-b" "$TASK_SUITE" read-b
"$TASK_TEMP/check-b" "$TASK_SUITE" cleanup
