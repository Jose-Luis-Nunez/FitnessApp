import SwiftUI
import UIKit

/// Thin `UIViewControllerRepresentable` wrapper around `UIActivityViewController`
/// so SwiftUI can present the standard iOS share sheet. Use via
/// `.sheet(item:)` driven by an `Identifiable` source (typically a Workout)
/// and pass `items` containing the exported JSON string or file URL.
///
/// Available on free Apple Developer accounts — `UIActivityViewController` is
/// standard UIKit, no entitlement required.
public struct ShareSheet: UIViewControllerRepresentable {
    public let items: [Any]
    /// Temp file to delete after the share sheet dismisses. Pass the URL
    /// returned by `WorkoutShareFileWriter.write(json:name:)` so it is cleaned
    /// up regardless of whether the user completes or cancels the share.
    public var tempFileURL: URL?

    public init(items: [Any], tempFileURL: URL? = nil) {
        self.items = items
        self.tempFileURL = tempFileURL
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { [url = tempFileURL] _, _, _, _ in
            if let url { try? FileManager.default.removeItem(at: url) }
        }
        return vc
    }

    public func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
        // Nothing dynamic to update — the controller is single-use per presentation.
    }
}
