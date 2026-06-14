#if canImport(UIKit)
import UIKit
#endif

/// Thin, platform-guarded wrapper around impact haptics so call sites don't each
/// repeat the `#if canImport(UIKit)` dance (the feature previously instantiated
/// `UIImpactFeedbackGenerator` inline in several views).
public enum Haptics {
    public enum ImpactStyle {
        case light, medium, heavy
    }

    public static func impact(_ style: ImpactStyle) {
        #if canImport(UIKit)
        let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light:  uiStyle = .light
        case .medium: uiStyle = .medium
        case .heavy:  uiStyle = .heavy
        }
        UIImpactFeedbackGenerator(style: uiStyle).impactOccurred()
        #endif
    }
}
