import SwiftData
import SwiftUI

struct WidgetSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\LiteApp.sortOrder), SortDescriptor(\LiteApp.createdAt)]) private var apps: [LiteApp]
    @State private var errorMessage: String?

    private var orderedApps: [LiteApp] {
        apps.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }
    private var selectedApps: [LiteApp] { orderedApps.filter(\.isVisibleInWidget) }
    private var previewApps: [LiteApp] { Array(selectedApps.prefix(3)) }

    var body: some View {
        List {
            Section {
                if previewApps.isEmpty {
                    ContentUnavailableView("Choose Your Shortcuts", systemImage: "rectangle.3.group", description: Text("Select apps below to preview your widget."))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                        ForEach(previewApps) { app in
                            VStack(spacing: 8) {
                                AppIconView(data: app.iconData, websiteURL: app.url, symbol: app.iconSymbol, size: 48)
                                    .accessibilityHidden(true)
                                Text(app.name).font(.caption).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 16)
                    .accessibilityIdentifier("widgets.preview")
                }
            } header: { Text("Medium Widget Preview") } footer: {
                Text("Small widgets show 1 app, medium 3, and large 6. Apps follow your library order, with favorites first.")
            }
            Section {
                if apps.isEmpty {
                    Text("Add a Lite App from Library or Discover first.").foregroundStyle(.secondary)
                }
                ForEach(orderedApps) { app in
                    Toggle(isOn: Binding(
                        get: { app.isVisibleInWidget },
                        set: { value in
                            let previous = app.isVisibleInWidget
                            app.isVisibleInWidget = value
                            do { try context.save() }
                            catch {
                                app.isVisibleInWidget = previous
                                errorMessage = "Your widget selection couldn’t be saved. Please try again."
                            }
                        }
                    )) {
                        HStack(spacing: 12) {
                            AppIconView(data: app.iconData, websiteURL: app.url, symbol: app.iconSymbol, size: 36)
                                .accessibilityHidden(true)
                            Text(app.name)
                        }
                    }
                    .accessibilityIdentifier("widgets.app.\(app.name)")
                }
            } header: { Text("Selected Apps · \(selectedApps.count)") } footer: {
                Text("Widget selection is separate from favorites. Selected app names and icons are visible on your Home Screen; opening locked apps still requires authentication.")
            }
            Section("Add to Your Home Screen") {
                Text("Touch and hold the Home Screen, choose Edit → Add Widget, and search for Lite. Choose a size and tap Add Widget.")
                    .font(.subheadline)
            }
            Section("Siri & Shortcuts") {
                Label("Open Lite App", systemImage: "arrow.up.forward.app")
                Text("In Apple’s Shortcuts app, add the Open Lite App action and choose any saved Lite App. Widget selection isn’t required.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Widgets & Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn’t Save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}
