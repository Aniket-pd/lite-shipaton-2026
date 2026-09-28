import AppIntents
import Foundation

struct LiteAppIntentEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Lite App")
    static let defaultQuery = LiteAppIntentQuery()

    let id: String
    let name: String
    let symbol: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }
}

struct LiteAppIntentQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [LiteAppIntentEntity] {
        let wanted = Set(identifiers)
        return entities().filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [LiteAppIntentEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entities() }
        return entities().filter { $0.name.localizedStandardContains(query) }
    }

    func suggestedEntities() async throws -> [LiteAppIntentEntity] { entities() }

    private func entities() -> [LiteAppIntentEntity] {
        LiteMetadataStore.shortcutEntries().map {
            LiteAppIntentEntity(id: $0.id.uuidString, name: $0.name, symbol: $0.iconSymbol)
        }
    }
}

struct OpenLiteAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Lite App"
    static let description = IntentDescription("Open a saved website profile inside Lite.")
    static let openAppWhenRun = true

    @Parameter(title: "Lite App") var app: LiteAppIntentEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$app)")
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: app.id) else { return .result() }
        await LiteMetadataStore.setPendingOpen(id)
        return .result()
    }
}

struct LiteAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenLiteAppIntent(),
            phrases: ["Open \(.applicationName)", "Open a Lite App in \(.applicationName)"],
            shortTitle: "Open Lite App",
            systemImageName: "square.grid.2x2"
        )
    }
}
