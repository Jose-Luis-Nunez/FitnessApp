import SwiftUI
import FitnessResources

/// Shared rendering for the exercise muscle artwork used by active cards and
/// the active-training sheet. Keeping the glow, crop, theme mapping, and tap
/// target here prevents the two live surfaces from drifting visually.
public struct ExerciseMuscleIconView: View {
    public let iconName: String
    public let alignment: Alignment
    public let allowsEditing: Bool
    public let accessibilityIdentifier: String
    public let onEdit: () -> Void
    public let size: CGFloat?
    /// Height of the artwork frame. `nil` keeps it square at `size`; the
    /// training sheet passes its column height so the figure fills the rail.
    public let height: CGFloat?
    /// Magnifies the artwork inside its frame, anchored to `alignment`, so a
    /// top-aligned figure grows into its torso and loses legs at the bottom.
    public let zoom: CGFloat
    public let showsGlow: Bool
    public let artwork: Image?

    @Environment(\.appColorTheme) private var appColorTheme

    public init(
        iconName: String,
        alignment: Alignment,
        allowsEditing: Bool,
        accessibilityIdentifier: String,
        size: CGFloat? = nil,
        height: CGFloat? = nil,
        zoom: CGFloat = 1,
        showsGlow: Bool = true,
        artwork: Image? = nil,
        onEdit: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.alignment = alignment
        self.allowsEditing = allowsEditing
        self.accessibilityIdentifier = accessibilityIdentifier
        self.size = size
        self.height = height
        self.zoom = zoom
        self.showsGlow = showsGlow
        self.artwork = artwork
        self.onEdit = onEdit
    }

    private var resolvedSize: CGFloat {
        size ?? AppStyle.DeviceLayout.exerciseIconSize
    }

    private var resolvedArtwork: Image {
        artwork ?? Image(appColorTheme.muscleIconName(for: iconName))
    }

    public var body: some View {
        VStack {
            ZStack {
                if showsGlow {
                    Circle()
                        .fill(appColorTheme.accent.black)
                        .frame(
                            width: resolvedSize * 0.9,
                            height: resolvedSize * 0.9
                        )
                        .blur(radius: AppStyle.Blur.iconGlow)
                        .opacity(AppStyle.Opacity.overlayBackdrop)
                }

                resolvedArtwork
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(
                        width: resolvedSize,
                        height: height ?? resolvedSize,
                        alignment: alignment
                    )
                    .scaleEffect(zoom, anchor: UnitPoint(alignment))
                    .frame(
                        width: resolvedSize,
                        height: height ?? resolvedSize
                    )
                    .clipped()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if allowsEditing { onEdit() }
            }
            .modifier(
                ExerciseMuscleIconAccessibilityModifier(
                    allowsEditing: allowsEditing,
                    onEdit: onEdit
                )
            )
            .accessibilityIdentifier(accessibilityIdentifier)
        }
        .frame(width: size ?? AppStyle.DeviceLayout.iconContainerWidth)
        .frame(maxHeight: .infinity)
    }
}

private struct ExerciseMuscleIconAccessibilityModifier: ViewModifier {
    let allowsEditing: Bool
    let onEdit: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if allowsEditing {
            content
                .accessibilityElement()
                .accessibilityLabel(AppText.accessibilityEditSeat)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    onEdit()
                }
        } else {
            content
                .accessibilityElement()
                .accessibilityLabel(AppText.accessibilityExerciseIllustration)
                .accessibilityAddTraits(.isImage)
        }
    }
}

private extension UnitPoint {
    /// The frame anchor that keeps the aligned edge fixed while scaling.
    init(_ alignment: Alignment) {
        switch alignment {
        case .top: self = .top
        case .bottom: self = .bottom
        case .leading: self = .leading
        case .trailing: self = .trailing
        case .topLeading: self = .topLeading
        case .topTrailing: self = .topTrailing
        case .bottomLeading: self = .bottomLeading
        case .bottomTrailing: self = .bottomTrailing
        default: self = .center
        }
    }
}
