@testable import Typeflux
import XCTest

@MainActor
final class SettingsViewModelPersonaTests: XCTestCase {
    private var originalLanguage: AppLanguage!

    override func setUp() {
        super.setUp()
        originalLanguage = AppLocalization.shared.language
    }

    override func tearDown() {
        AppLocalization.shared.setLanguage(originalLanguage)
        originalLanguage = nil
        super.tearDown()
    }

    func testInitialSelectionIsNoneWhenPersonaRewriteIsDisabled() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        XCTAssertNil(viewModel.selectedPersonaID)
        XCTAssertEqual(viewModel.activePersonaID, "")
        XCTAssertFalse(viewModel.personaRewriteEnabled)
    }

    func testSelectNonePersonaClearsDraftFields() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        viewModel.selectPersona(nil)

        XCTAssertNil(viewModel.selectedPersonaID)
        XCTAssertEqual(viewModel.personaDraftName, "")
        XCTAssertEqual(viewModel.personaDraftPrompt, "")
    }

    func testSelectingPersonaDoesNotAutoActivateWhenPersonaRewriteIsDisabled() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        let persona = try XCTUnwrap(viewModel.personas.first)
        viewModel.selectPersona(persona.id)

        XCTAssertEqual(viewModel.selectedPersonaID, persona.id)
        XCTAssertEqual(viewModel.activePersonaID, "")
        XCTAssertFalse(viewModel.personaRewriteEnabled)
    }

    func testSelectingSystemPersonaShowsResolvedLocalizedPrompt() throws {
        let suiteName = "SettingsViewModelPersonaTests.localizedPrompt.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.appLanguage = .simplifiedChinese
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        let persona = try XCTUnwrap(viewModel.personas.first(where: { $0.id == SettingsStore.defaultPersonaID }))
        viewModel.selectPersona(persona.id)

        XCTAssertTrue(viewModel.personaDraftPrompt.contains("人设语言模式：继承。"))
        XCTAssertTrue(viewModel.personaDisplayPrompt(for: persona).contains("保持整体语气专业、正式、自然。"))
        XCTAssertFalse(viewModel.personaDraftPrompt.contains("You are Typeflux AI"))
    }

    func testSystemPersonaSearchUsesResolvedLocalizedPrompt() throws {
        let suiteName = "SettingsViewModelPersonaTests.localizedSearch.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.appLanguage = .simplifiedChinese
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        viewModel.searchQuery = "口头填充词"

        XCTAssertTrue(viewModel.filteredPersonas.contains(where: { $0.id == SettingsStore.defaultPersonaID }))
    }

    func testChangingAppLanguageRefreshesSelectedSystemPersonaPrompt() throws {
        let suiteName = "SettingsViewModelPersonaTests.languageRefresh.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        viewModel.selectPersona(SettingsStore.defaultPersonaID)
        XCTAssertTrue(viewModel.personaDraftPrompt.contains("Persona language mode: inherit."))

        viewModel.setAppLanguage(.simplifiedChinese)

        XCTAssertTrue(viewModel.personaDraftPrompt.contains("人设语言模式：继承。"))
        XCTAssertFalse(viewModel.personaDraftPrompt.contains("You are Typeflux AI"))
    }

    func testDeactivatePersonaRewriteKeepsNonePersonaSelected() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        viewModel.selectPersona(nil)
        viewModel.deactivatePersonaRewrite()

        XCTAssertNil(viewModel.selectedPersonaID)
        XCTAssertEqual(viewModel.activePersonaID, "")
        XCTAssertFalse(viewModel.personaRewriteEnabled)
    }

    func testSavePersonaAppBindingPersistsBindingAndClearsDraft() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        let persona = try XCTUnwrap(viewModel.personas.first)
        viewModel.personaAppBindingDraftIdentifier = "com.tinyspeck.slackmacgap"
        viewModel.personaAppBindingDraftPersonaID = persona.id

        viewModel.savePersonaAppBinding()

        XCTAssertEqual(settingsStore.personaAppBindings.count, 1)
        XCTAssertEqual(settingsStore.personaAppBindings.first?.appIdentifier, "com.tinyspeck.slackmacgap")
        XCTAssertEqual(settingsStore.personaAppBindings.first?.personaID, persona.id)
        XCTAssertTrue(viewModel.personaAppBindingDraftIdentifier.isEmpty)
    }

    func testSavePersonaAppBindingAllowsNoPersonaSelection() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        viewModel.personaAppBindingDraftIdentifier = "com.apple.Notes"
        viewModel.personaAppBindingDraftPersonaID = nil

        viewModel.savePersonaAppBinding()

        XCTAssertEqual(settingsStore.personaAppBindings.count, 1)
        XCTAssertEqual(settingsStore.personaAppBindings.first?.appIdentifier, "com.apple.Notes")
        XCTAssertNil(settingsStore.personaAppBindings.first?.personaID)
        XCTAssertTrue(viewModel.personaAppBindingDraftIdentifier.isEmpty)
    }

    func testDeletePersonaRemovesAssociatedAppBindings() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let customPersona = PersonaProfile(name: "Chat Reply", prompt: "Be casual.")
        settingsStore.personas = settingsStore.personas + [customPersona]
        settingsStore.savePersonaAppBinding(
            appIdentifier: "com.tinyspeck.slackmacgap",
            personaID: customPersona.id
        )
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        viewModel.deletePersona(id: customPersona.id)

        XCTAssertTrue(settingsStore.personaAppBindings.isEmpty)
        XCTAssertTrue(viewModel.personaAppBindings.isEmpty)
    }

    func testSetPersonaAppBindingsEnabledUpdatesStore() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        viewModel.setPersonaAppBindingsEnabled(false)

        XCTAssertFalse(settingsStore.personaAppBindingsEnabled)
        XCTAssertFalse(viewModel.personaAppBindingsEnabled)
    }

    func testUpdatePersonaAppBindingPersonaUpdatesStore() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let originalPersona = PersonaProfile(name: "Casual", prompt: "Casual")
        let updatedPersona = PersonaProfile(name: "Formal", prompt: "Formal")
        settingsStore.personas = settingsStore.personas + [originalPersona, updatedPersona]
        settingsStore.savePersonaAppBinding(appIdentifier: "Slack", personaID: originalPersona.id)
        let bindingID = try XCTUnwrap(settingsStore.personaAppBindings.first?.id)
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        viewModel.updatePersonaAppBindingPersona(id: bindingID, personaID: updatedPersona.id)

        XCTAssertEqual(settingsStore.personaAppBindings.first?.personaID, updatedPersona.id)
        XCTAssertEqual(viewModel.personaAppBindings.first?.personaID, updatedPersona.id)
    }

    func testUpdatePersonaAppBindingPersonaCanDisablePersona() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let persona = PersonaProfile(name: "Casual", prompt: "Casual")
        settingsStore.personas = settingsStore.personas + [persona]
        settingsStore.savePersonaAppBinding(appIdentifier: "Slack", personaID: persona.id)
        let bindingID = try XCTUnwrap(settingsStore.personaAppBindings.first?.id)
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        viewModel.updatePersonaAppBindingPersona(id: bindingID, personaID: nil)

        XCTAssertNil(settingsStore.personaAppBindings.first?.personaID)
        XCTAssertNil(viewModel.personaAppBindings.first?.personaID)
    }

    func testSetPersonaAppBindingEnabledUpdatesStore() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let persona = try XCTUnwrap(settingsStore.personas.first)
        settingsStore.savePersonaAppBinding(appIdentifier: "Slack", personaID: persona.id)
        let bindingID = try XCTUnwrap(settingsStore.personaAppBindings.first?.id)
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .personas
        )

        viewModel.setPersonaAppBindingEnabled(id: bindingID, isEnabled: false)

        XCTAssertFalse(settingsStore.personaAppBindings.first?.isEnabled ?? true)
        XCTAssertFalse(viewModel.personaAppBindings.first?.isEnabled ?? true)
    }

    // MARK: - Auto persona default when LLM becomes configured via Settings

    func testApplyingOpenAIAPIKeyAutoSelectsTypefluxPersona() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .home
        )

        viewModel.setLLMRemoteProvider(LLMRemoteProvider.openAI)
        XCTAssertFalse(settingsStore.personaRewriteEnabled, "OpenAI without key should not trigger default")

        viewModel.setLLMAPIKey("sk-test")
        viewModel.applyModelConfiguration(shouldShowToast: false)

        XCTAssertTrue(settingsStore.personaRewriteEnabled)
        XCTAssertEqual(settingsStore.activePersonaID, SettingsStore.defaultPersonaID.uuidString)
    }

    func testExplicitlyDisabledPersonaStaysOffWhenLLMIsConfigured() throws {
        let suiteName = "SettingsViewModelPersonaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settingsStore = SettingsStore(defaults: defaults)
        let historyStore = InMemoryHistoryStore()
        let viewModel = StudioViewModel(
            settingsStore: settingsStore,
            historyStore: historyStore,
            initialSection: .home
        )

        // User explicitly turns persona off before configuring LLM.
        settingsStore.applyPersonaSelection(nil)

        viewModel.setLLMRemoteProvider(.openAI)
        viewModel.setLLMAPIKey("sk-test")
        viewModel.applyModelConfiguration(shouldShowToast: false)

        XCTAssertFalse(settingsStore.personaRewriteEnabled, "Explicit opt-out must be respected")
        XCTAssertEqual(settingsStore.activePersonaID, "")
    }
}

private final class InMemoryHistoryStore: HistoryStore {
    func save(record _: HistoryRecord) {}
    func list() -> [HistoryRecord] {
        []
    }

    func list(limit _: Int, offset _: Int, searchQuery _: String?) -> [HistoryRecord] {
        []
    }

    func record(id _: UUID) -> HistoryRecord? {
        nil
    }

    func delete(id _: UUID) {}
    func purge(olderThanDays _: Int) {}
    func clear() {}
    func exportMarkdown() throws -> URL {
        URL(fileURLWithPath: "/tmp/typeflux-history.md")
    }
}
