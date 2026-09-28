import SwiftData
import SwiftUI

struct LiteBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    let app: LiteApp
    var initialURL: URL? = nil
    @State private var session: WebSession?

    var body: some View {
        // Lifecycle modifiers belong to this stable container, not to the conditional
        // child. A Group would forward them to the loading/content branches.
        ZStack {
            if let session {
                LiteBrowserContent(app: app, session: session)
            } else {
                ProgressView("Opening…")
            }
        }
        .task {
            await ContainerWebsiteData.waitForCleanup(of: app.dataStoreIdentifier)
            guard !Task.isCancelled else { return }
            // SwiftUI can recreate view values often; allocate WebKit only when mounted.
            let mountedSession: WebSession
            if let session {
                mountedSession = session
            } else {
                mountedSession = WebSession(app: app, initialURL: initialURL) { url in
                    guard app.lastPageURL != url else { return }
                    app.lastPageURL = url
                    try? modelContext.save()
                }
                session = mountedSession
            }
            await mountedSession.start()
        }
        .onDisappear {
            session?.close()
            session = nil
        }
    }
}
