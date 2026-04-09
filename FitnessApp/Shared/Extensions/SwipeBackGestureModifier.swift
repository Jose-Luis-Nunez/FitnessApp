import SwiftUI

/// Re-enables the native iOS interactive pop gesture (swipe from left edge to go back)
/// which gets disabled when using `.navigationBarBackButtonHidden(true)`.
///
/// Uses a proper delegate to prevent the gesture on the root view controller,
/// avoiding the known freeze issue when swiping back with nothing to pop.
struct EnableSwipeBackModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(SwipeBackHelper())
    }
}

/// UIKit bridge that finds the hosting UINavigationController and
/// re-enables its `interactivePopGestureRecognizer` with a safe delegate.
private struct SwipeBackHelper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class SwipeBackViewController: UIViewController {
    private let gestureDelegate = SwipeBackGestureDelegate()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let nav = navigationController else { return }
        nav.interactivePopGestureRecognizer?.isEnabled = true
        nav.interactivePopGestureRecognizer?.delegate = gestureDelegate
    }
}

/// Custom delegate that only allows the swipe-back gesture when
/// the navigation stack has more than one view controller,
/// preventing the freeze that occurs when swiping on the root.
private final class SwipeBackGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let nav = gestureRecognizer.view as? UIView,
              let navController = nav.findNavigationController() else {
            return false
        }
        // Only allow swipe-back when there is something to pop
        return navController.viewControllers.count > 1
    }
}

private extension UIView {
    /// Walks up the responder chain to find the nearest UINavigationController.
    func findNavigationController() -> UINavigationController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let nav = next as? UINavigationController {
                return nav
            }
            responder = next
        }
        return nil
    }
}

// MARK: - View Extension

extension View {
    /// Enables the native iOS swipe-from-left-edge back gesture,
    /// even when the navigation bar back button is hidden.
    func enableSwipeBack() -> some View {
        modifier(EnableSwipeBackModifier())
    }
}
