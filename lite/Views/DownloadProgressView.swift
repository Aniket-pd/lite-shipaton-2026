import SwiftUI

struct DownloadProgressView: View {
    let download: WebDownload
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: download.errorMessage == nil ? "arrow.down.circle" : "exclamationmark.triangle")
                Text(download.errorMessage ?? download.filename).font(.subheadline).lineLimit(1)
                Spacer()
                Button(download.errorMessage == nil ? "Cancel" : "Dismiss", role: .cancel, action: cancel)
                    .font(.caption)
                    .disabled(download.isCancelling)
            }
            if download.errorMessage == nil {
                ProgressView(value: download.progress)
                    .accessibilityLabel("Downloading \(download.filename)")
            }
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
