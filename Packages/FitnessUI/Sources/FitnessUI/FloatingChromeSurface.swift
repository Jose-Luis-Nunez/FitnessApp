import SwiftUI

/// The one place the app's floating chrome colour is defined — the bottom bar's
/// plate and capsule, its side circles, and the Overview/List filter toggle that
/// floats at the same level. Sharing one definition is the point: these surfaces
/// sit next to each other on screen and drifted apart every time they each
/// described their own.
///
/// Warm rather than neutral on purpose: a cool grey over this page reads as a
/// dead slab. The plate runs a soft vertical ramp from a warmer smoke at the
/// top to near-black at the bottom; controls sit on it as a lighter, partly
/// transparent warm charcoal, which is what keeps them separated from the plate
/// without an opaque outline.
///
/// No outline on any of it. A rim, however faint, turns the material into a
/// framed plate; the surfaces separate from the page by blur and fill alone,
/// the same way the category tiles do.
///
/// Three earlier attempts are recorded here so they are not repeated: repainting
/// the screen's petrol wash put a green film over the chrome rather than light
/// behind it; resolving each surface's real position through a `GeometryReader`
/// reading its global frame wedged the bar badly enough that taps stopped
/// registering; and trading tint for a thinner, sheened surface read as flimsy,
/// not glassier.
public enum FloatingChromeSurface {
    /// Vertical smoke ramp for the plate. Four stops rather than two: a straight
    /// two-colour ramp over this distance shows a visible band through the middle.
    ///
    /// Top to bottom, not diagonal. The controls are partly transparent and
    /// inherit whatever the plate does beneath them; on the old diagonal the
    /// back button sat on the light end and melted into the plate while the
    /// trailing button sat on the dark end and stood out. Running the ramp
    /// vertically keeps the warm smoke behind the mini bar and puts the whole
    /// tab row on the same dark end, so both side buttons read alike.
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
    private static let controlFillOpacity: Double = 0.60

    /// The selected segment's pill, a step lighter than the control it sits in
    /// and warm in the same direction.
    public static let selectionFill = Color(hex: "#3A3533")

    /// Over the training sheet the chrome is literally the timer pill's
    /// surface: same colour, same opacity, and no material under it, so the
    /// bar and the dials over the artwork read as one set of instruments.
    private static let trainingSelectionFill = Color(hex: "#2E3134")

    /// Which palette the chrome uses. `floating` is the warm charcoal of the
    /// overview screens; `training` is the neutral grey of the training sheet.
    public enum Variant: Equatable, Sendable {
        case floating
        case training
    }

    public static func selectionFill(for variant: Variant) -> Color {
        switch variant {
        case .floating: selectionFill
        case .training: trainingSelectionFill
        }
    }

    /// The plate behind the bottom bar's mini bar and tab row.
    public static func plate<S: Shape>(in shape: S) -> some View {
        shape.fill(
            LinearGradient(
                colors: plateRamp,
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// A floating control: capsule or circle. Material plus a partly
    /// transparent fill on purpose: the fill keeps the colour, the material lets
    /// whatever scrolls beneath show through blurred.
    public static func control<S: InsettableShape>(
        in shape: S,
        variant: Variant = .floating
    ) -> some View {
        ZStack {
            switch variant {
            case .floating:
                shape.fill(.ultraThinMaterial)
                shape.fill(controlFill.opacity(controlFillOpacity))
            case .training:
                shape.fill(AppStyle.Color.trainingDialDisc)
                    .opacity(AppStyle.Opacity.trainingDialDisc)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}
