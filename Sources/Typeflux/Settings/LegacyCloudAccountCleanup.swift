import Foundation
import Security

enum LegacyCloudAccountCleanup {
    private static let migrationKey = "migration.cloudAccountRemoval.v1"
    private static let legacySTTProvider = "typefluxOfficial"
    private static let legacyLLMProvider = "typefluxCloud"

    static func runIfNeeded(defaults: UserDefaults) {
        guard !defaults.bool(forKey: migrationKey) else { return }

        if defaults.string(forKey: "stt.provider") == legacySTTProvider {
            defaults.set(STTProvider.defaultProvider.rawValue, forKey: "stt.provider")
        }
        if defaults.string(forKey: "llm.remote.provider") == legacyLLMProvider {
            defaults.set(LLMRemoteProvider.defaultProvider.rawValue, forKey: "llm.remote.provider")
        }

        defaults.removeObject(forKey: "typefluxCloud.loginReminder.lastShownAt")
        defaults.removeObject(forKey: "cloud.preferredAPIServer")
        defaults.removeObject(forKey: "cloud.preferredASRServer")
        if defaults === UserDefaults.standard {
            clearLegacyAccountCredentials()
        }
        defaults.set(true, forKey: migrationKey)
    }

    private static func clearLegacyAccountCredentials() {
        let bundleID = Bundle.main.bundleIdentifier ?? "ai.gulu.app.typeflux"
        let services = [
            "ai.gulu.app.typeflux.auth",
            "ai.gulu.app.typeflux.auth.v2",
            "ai.gulu.app.typeflux.auth.v1",
            "\(bundleID).auth"
        ]
        for service in Set(services) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
