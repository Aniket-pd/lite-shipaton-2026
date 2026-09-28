#if DEBUG
import Foundation
import SwiftData

/// In-memory, offline artwork for exercising group browsing. Normal launches
/// never call this fixture, and Release builds do not contain it.
enum AppGroupTestFixture {
    @MainActor static func seed(in context: ModelContext) throws {
        let services = [
            ("LinkedIn", "https://www.linkedin.com"),
            ("Gmail", "https://mail.google.com"),
            ("YouTube", "https://www.youtube.com"),
            ("Reddit", "https://www.reddit.com"),
            ("X", "https://x.com"),
            ("Instagram", "https://www.instagram.com"),
            ("Amazon", "https://www.amazon.com"),
            ("Reddit Personal", "https://www.reddit.com"),
            ("X Personal", "https://x.com")
        ]
        let apps = services.enumerated().map { index, service in
            let url = URL(string: service.1)!
            let app = LiteApp(
                name: service.0, url: url, iconData: CatalogIcon.data(for: url),
                isBiometricLocked: service.0 == "X"
            )
            app.sortOrder = index
            context.insert(app)
            return app
        }
        context.insert(LiteAppCollection(name: "Work", apps: Array(apps.prefix(5))))
        context.insert(LiteAppCollection(name: "Social", apps: [apps[5], apps[7], apps[8]], sortOrder: 1))
        context.insert(LiteAppCollection(name: "Shopping", apps: [apps[6]], sortOrder: 2))
        context.insert(LiteAppCollection(name: "Empty", apps: [], sortOrder: 3))
        try context.save()
    }
}
#endif
