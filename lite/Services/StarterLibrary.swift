import Foundation
import SwiftData

/// Starter profiles are installed only when a new user leaves onboarding.
/// Their bundled icons need no network access or website sign-in.
@MainActor
enum StarterLibrary {
    static let services = CatalogService.all.filter {
        ["instagram", "reddit", "x", "linkedin", "gmail", "youtube"].contains($0.id)
    }

    @discardableResult
    static func installIfEmpty(in context: ModelContext) throws -> Int {
        guard try context.fetchCount(FetchDescriptor<LiteApp>()) == 0 else { return 0 }
        for (index, service) in services.enumerated() {
            let url = URL(string: service.address)!
            let app = LiteApp(name: service.name, url: url, iconData: CatalogIcon.data(for: url),
                              iconSymbol: service.symbol, iconColor: service.color)
            app.sortOrder = index
            app.isStarterApp = true
            context.insert(app)
        }
        do {
            try context.save()
            return services.count
        } catch {
            context.rollback()
            throw error
        }
    }
}
