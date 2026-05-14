import SwiftUI
import UIKit

/// Thin `UIViewControllerRepresentable` wrapper around `UIActivityViewController`
/// so SwiftUI can present the standard iOS share sheet. Use via
/// `.sheet(item:)` driven by an `Identifiable` source (typically a Workout)
/// and pass `items` containing the exported JSON string or file URL.
///
/// Available on free Apple Developer accounts — `UIActivityViewController` is
/// standard UIKit, no entitlement required.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
        // Nothing dynamic to update — the controller is single-use per presentation.
    }
}
