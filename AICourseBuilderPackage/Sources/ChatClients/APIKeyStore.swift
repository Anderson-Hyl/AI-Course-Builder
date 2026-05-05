import Dependencies
import DependenciesMacros
import Foundation

/// Per-provider settings storage (API keys + optional override base
/// URLs). Backed by `UserDefaults.standard`:
/// - keys     → `com.aicoursebuilder.provider-keys.<provider>`
/// - base URL → `com.aicoursebuilder.provider-baseurls.<provider>`
///
/// **Why UserDefaults, not Keychain (yet)?** Per CLAUDE.md, ad-hoc-signed
/// dev builds have volatile code identities that orphan Keychain items
/// every time Xcode re-signs. UserDefaults survives those rebuilds.
/// Migration to Keychain lands once the project is on Developer ID
/// signing.
@DependencyClient
public struct APIKeyStore: Sendable {
    public var get: @Sendable (_ provider: ProviderID) throws -> String?
    public var set: @Sendable (_ provider: ProviderID, _ key: String) throws -> Void
    public var remove: @Sendable (_ provider: ProviderID) throws -> Void
    public var getBaseURL: @Sendable (_ provider: ProviderID) throws -> String?
    public var setBaseURL: @Sendable (_ provider: ProviderID, _ value: String) throws -> Void
}

extension APIKeyStore: DependencyKey {
    public static var liveValue: APIKeyStore {
        APIKeyStore(
            get: { provider in
                let storageKey = userDefaultsKey(for: provider)
                let value = UserDefaults.standard.string(forKey: storageKey)
                return (value?.isEmpty == false) ? value : nil
            },
            set: { provider, raw in
                let storageKey = userDefaultsKey(for: provider)
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    UserDefaults.standard.removeObject(forKey: storageKey)
                } else {
                    UserDefaults.standard.set(trimmed, forKey: storageKey)
                }
            },
            remove: { provider in
                UserDefaults.standard.removeObject(forKey: userDefaultsKey(for: provider))
            },
            getBaseURL: { provider in
                let storageKey = baseURLDefaultsKey(for: provider)
                let value = UserDefaults.standard.string(forKey: storageKey)
                return (value?.isEmpty == false) ? value : nil
            },
            setBaseURL: { provider, raw in
                let storageKey = baseURLDefaultsKey(for: provider)
                var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                while trimmed.hasSuffix("/") { trimmed.removeLast() }
                if trimmed.isEmpty {
                    UserDefaults.standard.removeObject(forKey: storageKey)
                } else {
                    UserDefaults.standard.set(trimmed, forKey: storageKey)
                }
            }
        )
    }

    public static var testValue: APIKeyStore { APIKeyStore() }
}

private func userDefaultsKey(for provider: ProviderID) -> String {
    "com.aicoursebuilder.provider-keys.\(provider.rawValue)"
}

private func baseURLDefaultsKey(for provider: ProviderID) -> String {
    "com.aicoursebuilder.provider-baseurls.\(provider.rawValue)"
}

extension DependencyValues {
    public var apiKeyStore: APIKeyStore {
        get { self[APIKeyStore.self] }
        set { self[APIKeyStore.self] = newValue }
    }
}
