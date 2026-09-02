import SwiftUI

/// Applies an accessibility identifier only when there is one to apply.
///
/// `accessibilityIdentifier("")` is not a no-op — it overwrites an identifier
/// inherited from an ancestor with an empty one, which leaves the element
/// unaddressable rather than merely unnamed.
///
/// Lives here rather than beside its callers because a second site needed it and
/// `FitnessExercise` had already grown a private copy.
public struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    public init(identifier: String?) {
        self.identifier = identifier
    }

    public func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
