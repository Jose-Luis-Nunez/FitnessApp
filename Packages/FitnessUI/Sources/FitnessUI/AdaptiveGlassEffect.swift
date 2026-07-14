import SwiftUI

enum AppGlassTreatment: Sendable {
    case legacyMaterial
    case regular
    case clear

    static var currentPlatform: Self {
#if os(visionOS)
        return .legacyMaterial
#else
        if #available(iOS 27.0, macOS 27.0, *) {
            return .clear
        }
        if #available(iOS 26.0, macOS 26.0, *) {
            return .regular
        }
        return .legacyMaterial
#endif
    }
}

enum AppDarkSurfaceTreatment: Sendable {
    case nativeGlass
    case flat

    static var currentPlatform: Self {
#if os(visionOS)
        return .nativeGlass
#else
        if #available(iOS 27.0, macOS 27.0, *) {
            return .flat
        }
        return .nativeGlass
#endif
    }
}

public extension View {
    /// Applies the app's cross-version Liquid Glass treatment.
    ///
    /// iOS 27's regular glass is intentionally more opaque and responds to the
    /// system Liquid Glass tint. The clear variant avoids that extra opacity,
    /// while older supported platforms keep the existing material fallback.
    @ViewBuilder
    func appGlassEffect<S: Shape>(in shape: S) -> some View {
        switch AppGlassTreatment.currentPlatform {
        case .legacyMaterial:
            background {
                shape.fill(.ultraThinMaterial)
            }
#if os(visionOS)
        case .regular, .clear:
            background {
                shape.fill(.ultraThinMaterial)
            }
#else
        case .regular:
            if #available(iOS 26.0, macOS 26.0, *) {
                glassEffect(.regular, in: shape)
            } else {
                background { shape.fill(.ultraThinMaterial) }
            }
        case .clear:
            if #available(iOS 27.0, macOS 27.0, *) {
                glassEffect(.clear, in: shape)
            } else {
                background { shape.fill(.ultraThinMaterial) }
            }
#endif
        }
    }

    /// Applies the app's restrained, dark surface treatment.
    ///
    /// iOS 27's specular Glass edge makes large app surfaces look like raised
    /// 3D bezels. This keeps native Glass on iOS 26 and earlier while using a
    /// deterministic dark fill and one neutral outline on iOS 27.
    @ViewBuilder
    func appDarkSurface<S: Shape>(
        backgroundColor: Color = AppStyle.Color.exerciseCardBackground,
        in shape: S
    ) -> some View {
        switch AppDarkSurfaceTreatment.currentPlatform {
        case .flat:
            background {
                ZStack {
                    shape.fill(backgroundColor.opacity(AppStyle.Opacity.darkSurfaceFill))
                    shape.fill(AppStyle.Color.black.opacity(AppStyle.Opacity.darkSurfaceDepth))
                }
            }
            .overlay {
                shape.stroke(
                    AppStyle.Color.white.opacity(AppStyle.Opacity.darkSurfaceOutline),
                    lineWidth: AppStyle.Layout.darkSurfaceOutlineWidth
                )
            }
        case .nativeGlass:
            background {
                ZStack {
                    shape.fill(backgroundColor)
                    Color.clear.appGlassEffect(in: shape)
                }
            }
        }
    }
}
