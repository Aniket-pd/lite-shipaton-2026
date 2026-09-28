import SwiftData
import SwiftUI
import WebKit

struct ContainerWebsiteDataView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    let app: LiteApp
    @State private var records: [WKWebsiteDataRecord] = []
    @State private var loaded = false
    @State private var isBusy = false
    @State private var action: DataAction?
    @State private var message: String?
    @State private var errorMessage: String?

    private enum DataAction: Identifiable {
        case cache, all, reset, record(WKWebsiteDataRecord)
        var id: String {
            switch self { case .cache: "cache"; case .all: "all"; case .reset: "reset"; case .record(let record): record.displayName }
        }
        var title: String {
            switch self {
            case .cache: "Clear Cache?"
            case .all: "Clear All Website Data?"
            case .reset: "Reset Container Preferences?"
            case .record(let record): "Remove data for \(record.displayName)?"
            }
        }
        var detail: String {
            switch self {
            case .cache: "Removes cached resources in this container. Cookies and website storage are kept. Offline content may need to download again."
            case .all: "Removes this container’s cookies, cached files and website storage, and forgets its last page and diagnostics. This usually signs you out. Its name, preferences and biometric lock are kept. Other containers are unaffected."
            case .reset: "Restores browsing, protection and website-permission preferences. Your name, icon, biometric lock, proxy settings and website data stay unchanged."
            case .record: "Removes the selected website’s stored data in this container. This may sign you out or affect other pages that depend on this website. Other containers are unaffected."
            }
        }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "externaldrive.fill").font(.largeTitle).foregroundStyle(.blue)
                    Text("Stored in this container").font(.headline)
                    Text("Website data stays separate from your other Lite apps.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }
            Section {
                if !loaded {
                    ProgressView("Reading website data…")
                } else if records.isEmpty {
                    Text("No website data stored").foregroundStyle(.secondary)
                        .accessibilityIdentifier("data.empty")
                } else {
                    ForEach(records, id: \.displayName) { record in
                        NavigationLink {
                            WebsiteDataRecordView(record: record) {
                                await perform(.record(record))
                            }
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.displayName)
                                    Text(ContainerWebsiteData.typeNames(for: record).joined(separator: ", "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: { Image(systemName: "globe").foregroundStyle(.secondary) }
                        }
                    }
                }
            } header: { Text(loaded ? "\(records.count) website records" : "Website records") } footer: {
                Text("WebKit groups stored data by website. Storage size isn’t provided by this interface.")
            }
            Section {
                Button("Clear Cache") { action = .cache }
                    .accessibilityIdentifier("data.clearCache")
            } header: { Text("Manage data") } footer: { Text("Remove cached resources to troubleshoot loading. Keeps cookies and sign-ins.") }
            Section {
                Button("Clear All Website Data", role: .destructive) { action = .all }
                    .accessibilityIdentifier("data.clearAll")
            } footer: { Text("Removes this container’s local website session and usually signs you out.") }
            Section {
                Button("Reset Container Preferences") { action = .reset }
                    .accessibilityIdentifier("data.reset")
            }
            if isBusy { Section { ProgressView("Updating container…") } }
            if let message { Section { Text(message).font(.footnote).foregroundStyle(.secondary) } }
        }
        .disabled(isBusy)
        .navigationTitle("Website Data")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Refresh", systemImage: "arrow.clockwise") { Task { await refresh() } }.disabled(isBusy) }
        .interactiveDismissDisabled(isBusy)
        .task { await refresh() }
        .confirmationDialog(action?.title ?? "Manage Website Data", isPresented: Binding(
            get: { action != nil }, set: { if !$0 { action = nil } }
        ), titleVisibility: .visible, presenting: action) { selected in
            Button(selected.id == "reset" ? "Reset Preferences" : "Clear Data", role: .destructive) {
                action = nil
                Task { await perform(selected) }
            }
            Button("Cancel", role: .cancel) { action = nil }
        } message: { selected in Text(selected.detail) }
        .alert("Couldn’t Update Container", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let fetched = await ContainerWebsiteData.records(for: app.dataStoreIdentifier)
        guard !Task.isCancelled else { return }
        records = fetched
        loaded = true
    }

    private func perform(_ selected: DataAction) async {
        guard !isBusy, scenePhase == .active else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        switch selected {
        case .reset:
            do {
                _ = try await ContentBlocker.rules()
                guard scenePhase == .active else { return }
                app.resetContainerPreferences()
                try context.save()
                message = "Container preferences reset. Website data and the biometric lock were kept."
            } catch {
                context.rollback()
                errorMessage = "Preferences couldn’t be reset. Please try again."
            }
        case .all:
            app.lastPageURL = nil
            app.clearDiagnostics()
            do { try context.save() }
            catch { context.rollback(); errorMessage = "The saved session metadata couldn’t be cleared. No website data was removed."; return }
            await ContainerWebsiteData.remove(.all, from: app.dataStoreIdentifier)
            message = "Website-data cleanup completed. The records below have been refreshed."
        case .cache:
            await ContainerWebsiteData.remove(.cache, from: app.dataStoreIdentifier)
            message = "Cached resources cleared. Cookies and other website storage were kept."
        case .record(let record):
            await ContainerWebsiteData.remove(.record(record), from: app.dataStoreIdentifier)
            message = "Website-data cleanup completed for \(record.displayName)."
        }
        records = await ContainerWebsiteData.records(for: app.dataStoreIdentifier)
        loaded = true
    }
}

private struct WebsiteDataRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let record: WKWebsiteDataRecord
    let remove: () async -> Void
    @State private var confirming = false
    @State private var isRemoving = false

    var body: some View {
        Form {
            Section("Website") { Text(record.displayName).textSelection(.enabled) }
            Section("Stored data types") {
                ForEach(ContainerWebsiteData.typeNames(for: record), id: \.self) { Text($0) }
            }
            Section {
                Button("Remove This Website’s Data", role: .destructive) { confirming = true }
                    .disabled(isRemoving)
                if isRemoving { ProgressView("Removing website data…") }
            }
        }
        .navigationTitle("Website Record")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isRemoving)
        .confirmationDialog("Remove data for \(record.displayName)?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Clear Data", role: .destructive) {
                guard scenePhase == .active else { return }
                isRemoving = true
                Task {
                    await remove()
                    isRemoving = false
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Removes this website’s data from this container. This may sign you out or affect pages that depend on this website. Other containers are unaffected.")
        }
    }
}
