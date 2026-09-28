//
//  liteApp.swift
//  lite
//
//  Created by Aniket prasad on 18/9/26.
//

import SwiftData
import SwiftUI
import OSLog

@main
struct LiteApplication: App {
    @AppStorage("lite.appearance") private var appearance: LiteAppearance = .system
    private let container: ModelContainer?
    @Environment(\.scenePhase) private var scenePhase
    @State private var pro = ProStore.applicationStore()
    @State private var openCoordinator = AppOpenCoordinator()

    init() {
        OnboardingPolicy.prepareForLaunch()
        // One scene owns all transfers. Files left by a terminated previous
        // process are not resumable and must not become a hidden download cache.
        try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory
            .appendingPathComponent("LiteDownloads", isDirectory: true))
        let inMemory: Bool
        #if DEBUG
        inMemory = ProcessInfo.processInfo.arguments.contains("--uitesting")
        #else
        inMemory = false
        #endif
        let schema = Schema([LiteApp.self, LiteAppCollection.self, PendingProfileDeletion.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        let logger = Logger(subsystem: "aniket.lite", category: "Persistence")
        var resolvedContainer: ModelContainer?

        do {
            let createdContainer = try ModelContainer(for: schema, configurations: [configuration])
            #if DEBUG
            if inMemory, ProcessInfo.processInfo.arguments.contains("--uitesting-saved-fixture") {
                try SavedContentTestFixture.seed(in: createdContainer.mainContext)
            } else if inMemory, ProcessInfo.processInfo.arguments.contains("--uitesting-groups-fixture") {
                try AppGroupTestFixture.seed(in: createdContainer.mainContext)
            } else if inMemory, ProcessInfo.processInfo.arguments.contains("--uitesting-locked-fixture") {
                let context = createdContainer.mainContext
                let unlocked = LiteApp(name: "Public Fixture", url: URL(string: "https://example.com")!)
                unlocked.id = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA1")!
                let locked = LiteApp(name: "Locked Fixture", url: unlocked.url, isBiometricLocked: true)
                locked.id = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA2")!
                context.insert(unlocked)
                context.insert(locked)
                try context.save()
            }
            #endif
            resolvedContainer = createdContainer
        } catch {
            // Never replace an unreadable on-disk library with an empty one.
            logger.error("Model container creation failed: \(String(describing: error), privacy: .public)")
            if !inMemory {
                do {
                    if let backup = try SwiftDataStoreRecovery
                        .repairInterruptedCollectionMigration(at: configuration.url) {
                        logger.notice("Repaired interrupted collection migration; backup: \(backup.path, privacy: .private)")
                        resolvedContainer = try ModelContainer(for: schema, configurations: [configuration])
                    }
                } catch {
                    logger.error("Model container recovery failed: \(String(describing: error), privacy: .public)")
                }
            }
        }
        container = resolvedContainer
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                HomeView()
                    .modelContainer(container)
                    .environment(openCoordinator)
                    .environment(pro)
                    .task { await pro.observePurchases() }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active { Task { await pro.refresh() } }
                    }
                    .tint(.blue)
                    .preferredColorScheme(appearance.colorScheme)
                    .onOpenURL { openCoordinator.handle($0) }
            } else {
                ContentUnavailableView {
                    Label("Your library couldn’t open", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Restart Lite and try again. Your saved apps have not been removed.")
                }.padding()
            }
        }
    }
}
