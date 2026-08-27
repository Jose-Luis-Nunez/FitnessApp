import SwiftUI

/// Screen-level atmospheric background: a near-black base carrying two very
/// large, very soft colour washes — desaturated petrol from the bottom-leading
/// corner, warm amber from the trailing edge — plus a subtle black vignette.
///
/// Deliberately calibrated to sit just at the edge of perception. Both washes
/// are anchored *outside* the visible bounds, so no gradient centre is ever
/// visible, and each decays along a gaussian-like stop curve rather than a
/// linear ramp, which is what keeps the falloff from reading as an edge.
/// Radii are kept well below the layout diagonal on purpose: a wash that
/// reaches the opposite corner stops being a wash and becomes a flat colour
/// cast over the whole screen, which also swallows the other wash.
///
/// Use one instance as the bottom layer of a screen's `ZStack`; it must not be
/// applied per row, otherwise the wash restarts for every cell and stops
/// reading as one continuous surface.
public struct AmbientScreenBackground: View {
    public init() {}

    /// Opacity multipliers approximating a gaussian falloff. A plain two-stop
    /// gradient decays linearly and shows a visible ring; this decays fast
    /// early and long in the tail, so the wash fades out without a boundary.
    private static let falloff: [(location: CGFloat, factor: Double)] = [
        (0.00, 1.00),
        (0.25, 0.62),
        (0.50, 0.30),
        (0.75, 0.10),
        (1.00, 0.00)
    ]

    public var body: some View {
        GeometryReader { proxy in
            let diagonal = (proxy.size.width * proxy.size.width
                + proxy.size.height * proxy.size.height).squareRoot()

            ZStack {
                AppStyle.Color.ambientBase

                // Additive blending over a near-black base keeps the falloff
                // smooth; normal alpha blending bands visibly at this size.
                // The wider of the two on purpose: the petrol carries the
                // surface, so it may reach across the lower half — but its
                // radius still stops it short of the opposite corner, where it
                // would become a flat cast instead of a wash.
                wash(
                    color: AppStyle.Color.ambientCool,
                    peak: AppStyle.Opacity.ambientCoolWash,
                    center: UnitPoint(x: -0.05, y: 1.10),
                    endRadius: diagonal * 0.55
                )
                .blendMode(.plusLighter)

                // Tighter than the cool wash: the warm side must stay a
                // localized glow on the trailing edge instead of bleeding
                // across the full width and neutralising the petrol.
                wash(
                    color: AppStyle.Color.ambientWarm,
                    peak: AppStyle.Opacity.ambientWarmWash,
                    center: UnitPoint(x: 1.10, y: 0.33),
                    endRadius: diagonal * 0.48
                )
                .blendMode(.plusLighter)

                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.55),
                        .init(color: AppStyle.Color.black.opacity(AppStyle.Opacity.ambientVignette), location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: diagonal * 0.75
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func wash(
        color: Color,
        peak: Double,
        center: UnitPoint,
        endRadius: CGFloat
    ) -> some View {
        RadialGradient(
            gradient: Gradient(stops: Self.falloff.map { stop in
                Gradient.Stop(
                    color: color.opacity(peak * stop.factor),
                    location: stop.location
                )
            }),
            center: center,
            startRadius: 0,
            endRadius: endRadius
        )
    }
}

public extension View {
    /// Places the shared ambient screen backdrop behind this view.
    ///
    /// Prefer this over inserting `AmbientScreenBackground` as a `ZStack` child.
    /// It is layout-neutral by construction — the backdrop lives in a
    /// `background`, so it cannot influence the content's alignment or sizing —
    /// and it removes the ordering trap where a call site has to know the
    /// backdrop must be the stack's *first* child to sit behind everything.
    ///
    /// The backdrop carries its own `ignoresSafeArea`, so it still extends under
    /// the status bar and bottom bar from here.
    ///
    /// Screen-scoped: apply it once per screen, never per row or cell — the
    /// washes are calibrated against the measured diagonal and restart per
    /// application, so a per-cell backdrop stops reading as one surface.
    ///
    /// Bottom sheets are not an exception, but they must not reach for this
    /// modifier directly: use `AmbientSheetSurface`, which pairs the backdrop
    /// with the shared sheet shape and border.
    func ambientScreenBackground() -> some View {
        background(AmbientScreenBackground())
    }
}

#Preview {
    AmbientScreenBackground()
}
