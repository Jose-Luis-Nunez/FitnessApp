import SwiftUI

/// The in-progress counterpart to `IdlePlayButton`: same circle, same ring, same
/// footprint, so a card switching between "not started" and "running" never
/// changes shape — only the glyph and the disc behind it.
///
/// The disc carries `FloatingChromeSurface`'s plate gradient, the same surface
/// the training mini bar is drawn on. That is the tie: the mini bar is the way
/// back into the running exercise, and this button marks the exercise it belongs
/// to, so they are deliberately the same material.
public struct IdlePauseButton: View {

    public init() {}

    public var body: some View {
        CardActionCircleButtonVisual(
            iconSize: AppStyle.Layout.idlePlayIconSize,
            discSize: AppStyle.Layout.idlePlayButtonSize,
            frameSize: AppStyle.Layout.idlePlayButtonGlowSize,
            surface: .clear
        ) {
            Image(systemName: "pause.fill")
                .resizable()
                .scaledToFit()
        }
        .background {
            FloatingChromeSurface.plate(in: Circle())
                .frame(
                    width: AppStyle.Layout.idlePlayButtonSize,
                    height: AppStyle.Layout.idlePlayButtonSize
                )
        }
    }
}
