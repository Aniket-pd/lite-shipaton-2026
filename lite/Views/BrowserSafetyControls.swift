import SwiftUI

/// Native controls stay outside website content, including full-page ad overlays.
struct BrowserWindowNotice: View {
    let session: WebSession
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if let pending = session.pendingWindow {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if typeSize.isAccessibilitySize {
                        Text("Open another window?")
                    } else {
                        Label("Open another window?", systemImage: "rectangle.on.rectangle")
                    }
                }
                .font(.subheadline.weight(.semibold))
                Text(pending.destinationLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 8) {
                        openButton
                        HStack { dismissButton; windowOptions(pending) }
                    }
                } else {
                    HStack {
                        openButton
                        dismissButton
                        Spacer(minLength: 0)
                        windowOptions(pending)
                    }
                }
            }
            .padding(.horizontal).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .accessibilityElement(children: .contain)
        } else if let notice = session.protectionNotice {
            HStack {
                Label(notice, systemImage: "hand.raised.fill")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("browser.protectionNotice")
                Spacer(minLength: 0)
                Button { session.dismissProtectionNotice() } label: {
                    Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel("Dismiss notice")
            }
            .padding(.horizontal)
            .background(.regularMaterial)
        }
    }

    private var openButton: some View {
        Button { session.approvePendingWindow() } label: {
            Text("Open").fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("browser.openWindow")
    }

    private var dismissButton: some View {
        Button { session.dismissPendingWindow() } label: {
            Text("Dismiss").fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: 30)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("browser.dismissWindow")
    }

    @ViewBuilder
    private func windowOptions(_ pending: PendingWebsiteWindow) -> some View {
        if let origin = pending.sourceOrigin {
            Menu {
                Button("Always allow windows from \(origin)") {
                    session.approvePendingWindow(alwaysAllow: true)
                }
            } label: {
                Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Website window options")
            .accessibilityIdentifier("browser.windowOptions")
        }
    }
}

struct BrowserReturnControls: View {
    let session: WebSession

    var body: some View {
        VStack(spacing: 4) {
            if session.isShowingPopup {
                Button { session.closePopup() } label: {
                    Label("Close popup and return", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44).contentShape(.rect)
                }
                    .accessibilityIdentifier("browser.closeWindow")
            } else if session.activePage.recoveryURL != nil && !session.activePage.canGoBack {
                Button { session.returnToPreviousPage() } label: {
                    Label("Return to previous page", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44).contentShape(.rect)
                }
                    .accessibilityHint("Restores the previous page. A reload may be needed.")
                    .accessibilityIdentifier("browser.recover")
            }
        }
        .padding(.horizontal)
        .background(.regularMaterial)
    }
}
