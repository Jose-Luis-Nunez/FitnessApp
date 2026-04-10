import SwiftUI

#if canImport(UIKit)
import UIKit

public struct EnableSwipeBackModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(SwipeBackHelper())
    }
}

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

private final class SwipeBackGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let nav = gestureRecognizer.view as? UIView,
              let navController = nav.findNavigationController() else {
            return false
        }
        return navController.viewControllers.count > 1
    }
}

private extension UIView {
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

extension View {
    public func enableSwipeBack() -> some View {
        modifier(EnableSwipeBackModifier())
    }
}
#else
extension View {
    public func enableSwipeBack() -> some View {
        self
    }
}
#endif
