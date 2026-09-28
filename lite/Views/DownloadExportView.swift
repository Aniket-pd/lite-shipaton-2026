import SwiftUI
import UIKit

struct DownloadExportView: UIViewControllerRepresentable {
    let fileURL: URL
    let completion: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let completion: () -> Void
        init(completion: @escaping () -> Void) { self.completion = completion }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { completion() }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { completion() }
    }
}
