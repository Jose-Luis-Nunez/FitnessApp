import SwiftUI

/// The one place the app's floating chrome colour is defined — the bottom bar's
/// plate and capsule, its side circles, and the Overview/List filter toggle that
/// floats at the same level. Sharing one definition is the point: these surfaces
/// sit next to each other on screen and drifted apart every time they each
/// described their own.
///
/// Warm rather than neutral on purpose: a cool grey over this page reads as a
/// dead slab. The plate runs a soft diagonal from a warmer smoke at the leading
/// top to near-black at the trailing bottom; controls sit on it as a lighter,
/// partly transparent warm charcoal with a faint light rim, which is what keeps
/// them separated from the plate without an opaque outline.
///
/// Three earlier attempts are recorded here so they are not repeated: repainting
/// the screen's petrol wash put a green film over the chrome rather than light
/// behind it; resolving each surface's real position through a `GeometryReader`
/// reading its global frame wedged the bar badly enough that taps stopped
/// registering; and trading tint for a thinner, sheened surface read as flimsy,
/// not glassier.
public enum FloatingChromeSurface {
    /// Diagonal smoke ramp for the plate. Four stops rather than two: a straight
    /// two-colour ramp over this distance shows a visible band through the middle.
    private static let plateRamp: [Color] = [
        Color(hex: "#2D2725"),
        Color(hex: "#262423"),
        Color(hex: "#1D1C1C"),
        Color(hex: "#131313")
    ]

    /// Warm charcoal for controls. Left partly transparent so the plate — or the
    /// page, where there is no plate — still carries through and the control
    /// reads as sitting *on* something.
    private static let controlFill = Color(hex: "#242120")
    private static let controlFillOpacity: Double = 0.72
    /// A rim rather than an outline: barely there, and only to separate the
    /// control from whatever is behind it.
    private static let controlRimOpacity: Double = 0.10

    /// The selected segment's pill, a step lighter than the control it sits in
    /// and warm in the same direction.
    public static let selectionFill = Color(hex: "#3A3533")

    /// The plate behind the bottom bar's mini bar and tab row.
    public static func plate<S: Shape>(in shape: S) -> some View {
        shape.fill(
            LinearGradient(
                colors: plateRamp,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    /// A floating control: capsule or circle.
    public static func control<S: InsettableShape>(in shape: S) -> some View {
        ZStack {
            shape.fill(.ultraThinMaterial)

            shape.fill(controlFill.opacity(controlFillOpacity))

            shape.strokeBorder(
                AppStyle.Color.white.opacity(controlRimOpacity),
                lineWidth: AppStyle.Layout.darkSurfaceOutlineWidth
            )
        }
        .environment(\.colorScheme, .dark)
    }
}
