import SwiftData
import SwiftUI

@Observable
@MainActor
final class CreateAppViewModel {
    var name = ""
    private(set) var websiteName = "Website"
    var url: URL?
    var iconData: Data?
    var symbol = "globe"
    var badgeColor = "blue"
    var useWebsiteIcon = true
    var isBiometricLocked = false
    var isFetchingIcon = false
    var isSaving = false
    var errorMessage: String?
    var proFeature: ProFeature?
    let biometrics = BiometricService()

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canCreate: Bool { url != nil && !trimmedName.isEmpty && trimmedName.count <= 40 && !isSaving && !isFetchingIcon }

    func configure(url: URL, service: CatalogService?) {
        self.url = url
        websiteName = service?.name ?? LiteAppGrouping.suggestedWebsiteName(for: url)
        name = "Personal"
        symbol = "globe"
        badgeColor = "blue"
        iconData = CatalogIcon.data(for: url)
        useWebsiteIcon = true
    }

    func fetchIcon() async {
        guard let url else { return }
        if let bundled = CatalogIcon.data(for: url) { iconData = bundled; return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            useWebsiteIcon = false
            return
        }
        #endif
        isFetchingIcon = true
        defer { isFetchingIcon = false }
        let data = await FaviconService().fetch(for: url)
        guard !Task.isCancelled, self.url == url else { return }
        iconData = data
        if data == nil { useWebsiteIcon = false }
    }

    func create(in context: ModelContext, pro: ProStore) async -> Bool {
        guard canCreate, let url else { return false }
        isSaving = true
        defer { isSaving = false }
        if isBiometricLocked {
            do { try await biometrics.authenticate(reason: "Protect \(trimmedName) with biometrics.") }
            catch { errorMessage = BiometricService.message(for: error); return false }
        }
        guard !Task.isCancelled else { return false }
        do {
            try pro.requireAppSlot(in: context)
            try pro.requireAppearance(symbol: symbol, color: badgeColor)
        } catch let feature as ProFeature { proFeature = feature; return false }
        catch { errorMessage = "Your library couldn’t be checked. Please try again."; return false }
        let app = LiteApp(name: trimmedName, url: url, iconData: useWebsiteIcon ? iconData : nil,
                          iconSymbol: symbol, iconColor: badgeColor, isBiometricLocked: isBiometricLocked)
        let existing = (try? context.fetch(FetchDescriptor<LiteApp>())) ?? []
        app.sortOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        context.insert(app)
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            errorMessage = "Your Lite App couldn’t be saved. Please try again."
            return false
        }
    }
}
