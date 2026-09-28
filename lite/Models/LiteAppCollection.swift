import Foundation
import SwiftData

/// A user-created collection of Lite Apps. Membership only references existing
/// apps; each app keeps its independent WebKit profile and settings.
@Model
final class LiteAppCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var sortOrder: Int
    @Relationship(deleteRule: .nullify) var apps: [LiteApp]

    init(
        name: String,
        apps: [LiteApp],
        sortOrder: Int = 0,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.apps = apps
    }

    var orderedApps: [LiteApp] {
        apps.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
