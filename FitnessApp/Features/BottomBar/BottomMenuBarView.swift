import SwiftUI
/*
enum NavigationDestination {
    case home
    case profile
}
 */

struct BottomMenuBarView: View {
    let barHeight: CGFloat
    let onAddExercise: () -> Void
    let backgroundColor: Color
    private let iconOffset: CGFloat = 12
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ZStack(alignment: .center) {
            backgroundColor
                .ignoresSafeArea(edges: .bottom)
                .frame(height: barHeight)
            
            HStack(spacing: AppStyle.Padding.horizontal) {
                Button(action: {
                    if !navigationPath.isEmpty {
                        navigationPath.removeLast()
                    }
                }) {
                    Image(systemName: "house")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: barHeight * 0.6)
                        .foregroundColor(AppStyle.Color.white)
                }

                Image(systemName: "chart.bar")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: barHeight * 0.6)
                    .foregroundColor(AppStyle.Color.white)

                Image(systemName: "calendar")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: barHeight * 0.6)
                    .foregroundColor(AppStyle.Color.white)

                Button(action: {
                    navigationPath.append(NavigationDestination.profile)
                }) {
                    Image(systemName: "person")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: barHeight * 0.6)
                        .foregroundColor(AppStyle.Color.white)
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .offset(y: iconOffset)
        }
    }
}
