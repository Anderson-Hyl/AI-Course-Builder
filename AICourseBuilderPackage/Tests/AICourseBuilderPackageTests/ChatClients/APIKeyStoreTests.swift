import ChatClients
import Foundation
import Testing

/// `APIKeyStore.liveValue` reads/writes `UserDefaults.standard`. The
/// suite is marked `.serialized` because every test mutates the same
/// global key (`com.aicoursebuilder.provider-keys.anthropic`); parallel
/// runs would race on it. Each test also clears the key before AND
/// after so a leftover from a prior crash doesn't poison the run.
@Suite("APIKeyStore liveValue", .serialized)
struct APIKeyStoreTests {

    @Test func setThenGetReturnsValue() throws {
        cleanupKey()
        defer { cleanupKey() }
        let store = APIKeyStore.liveValue
        try store.set(.anthropic, "sk-ant-test")
        #expect(try store.get(provider: .anthropic) == "sk-ant-test")
    }

    @Test func setEmptyStringClearsKey() throws {
        cleanupKey()
        defer { cleanupKey() }
        let store = APIKeyStore.liveValue
        try store.set(.anthropic, "sk-ant-existing")
        try store.set(.anthropic, "")
        #expect(try store.get(provider: .anthropic) == nil)
    }

    @Test func setWhitespaceOnlyClearsKey() throws {
        cleanupKey()
        defer { cleanupKey() }
        let store = APIKeyStore.liveValue
        try store.set(.anthropic, "sk-ant-existing")
        try store.set(.anthropic, "   \n  ")
        #expect(try store.get(provider: .anthropic) == nil)
    }

    @Test func removeClearsKey() throws {
        cleanupKey()
        defer { cleanupKey() }
        let store = APIKeyStore.liveValue
        try store.set(.anthropic, "sk-ant-existing")
        try store.remove(.anthropic)
        #expect(try store.get(provider: .anthropic) == nil)
    }

    @Test func setTrimsLeadingTrailingWhitespace() throws {
        cleanupKey()
        defer { cleanupKey() }
        let store = APIKeyStore.liveValue
        try store.set(.anthropic, "  sk-ant-trimmed  ")
        #expect(try store.get(provider: .anthropic) == "sk-ant-trimmed")
    }

    private func cleanupKey() {
        UserDefaults.standard.removeObject(forKey: "com.aicoursebuilder.provider-keys.anthropic")
        UserDefaults.standard.synchronize()
    }
}
