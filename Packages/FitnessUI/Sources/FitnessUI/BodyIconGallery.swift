import SwiftUI

/// Swipeable, paged gallery of body-image asset names over a dotted-ring
/// `MuscleIconBackdrop`. With more than one image the user pages left/right
/// (with the native page dots); with a single image it renders statically.
///
/// Shared by the exercise picker (icons of one muscle category) and the
/// new-workout sheet (the default icon of each muscle group).
public struct BodyIconGallery: View {
    private let icons: [String]
    @Binding private var selection: String
    private let height: CGFloat

    public init(icons: [String], selection: Binding<String>, height: CGFloat = 260) {
        self.icons = icons
        self._selection = selection
        self.height = height
    }

    public var body: some View {
        ZStack {
            MuscleIconBackdrop()
            gallery
        }
        .frame(height: height)
    }

    @ViewBuilder
    private var gallery: some View {
        if icons.count > 1 {
            TabView(selection: $selection) {
                ForEach(icons, id: \.self) { icon in
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .tag(icon)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            #endif
            .frame(height: height)
        } else {
            Image(icons.first ?? "")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()
        }
    }
}
