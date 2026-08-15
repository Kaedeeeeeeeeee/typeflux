@testable import Typeflux
import XCTest

final class LegacyCloudAccountCleanupTests: XCTestCase {
    func testMigratesLegacyProvidersAndRemovesCloudPreferences() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("typefluxOfficial", forKey: "stt.provider")
        defaults.set("typefluxCloud", forKey: "llm.remote.provider")
        defaults.set(Date(), forKey: "typefluxCloud.loginReminder.lastShownAt")
        defaults.set("https://api.example.com", forKey: "cloud.preferredAPIServer")
        defaults.set("https://asr.example.com", forKey: "cloud.preferredASRServer")

        LegacyCloudAccountCleanup.runIfNeeded(defaults: defaults)

        XCTAssertEqual(defaults.string(forKey: "stt.provider"), STTProvider.localModel.rawValue)
        XCTAssertEqual(defaults.string(forKey: "llm.remote.provider"), LLMRemoteProvider.openAI.rawValue)
        XCTAssertNil(defaults.object(forKey: "typefluxCloud.loginReminder.lastShownAt"))
        XCTAssertNil(defaults.object(forKey: "cloud.preferredAPIServer"))
        XCTAssertNil(defaults.object(forKey: "cloud.preferredASRServer"))
        XCTAssertTrue(defaults.bool(forKey: "migration.cloudAccountRemoval.v1"))
    }

    func testPreservesCurrentProviders() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(STTProvider.deepgram.rawValue, forKey: "stt.provider")
        defaults.set(LLMRemoteProvider.anthropic.rawValue, forKey: "llm.remote.provider")

        LegacyCloudAccountCleanup.runIfNeeded(defaults: defaults)

        XCTAssertEqual(defaults.string(forKey: "stt.provider"), STTProvider.deepgram.rawValue)
        XCTAssertEqual(defaults.string(forKey: "llm.remote.provider"), LLMRemoteProvider.anthropic.rawValue)
    }

    func testRunsOnlyOnce() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        LegacyCloudAccountCleanup.runIfNeeded(defaults: defaults)
        defaults.set("typefluxOfficial", forKey: "stt.provider")

        LegacyCloudAccountCleanup.runIfNeeded(defaults: defaults)

        XCTAssertEqual(defaults.string(forKey: "stt.provider"), "typefluxOfficial")
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "LegacyCloudAccountCleanupTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
