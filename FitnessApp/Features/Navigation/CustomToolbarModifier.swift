import SwiftUI

struct CustomToolbarModifier: ViewModifier {
    @Binding var navigationPath: NavigationPath
    let title: String
    let showBackButton: Bool

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(AppStyle.Color.backgroundColor, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(AppStyle.Font.navigationHeadline)
                        .foregroundColor(AppStyle.Color.white)
                }
                if showBackButton {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            if !navigationPath.isEmpty {
                                navigationPath.removeLast()
                            } else {
                                // If navigation path is empty, navigate to workouts screen
                                navigationPath.append(NavigationDestination.workouts)
                            }
                        }) {
                            ZStack(alignment: .center) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(AppStyle.Color.white)
                                    .imageScale(.large)
                            }
                            // Reduce horizontal padding by another 2px
                            .frame(width: 37, height: 44, alignment: .center)
                            .contentShape(Rectangle())
                            .accessibilityLabel("Back")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
    }
}

extension View {
    func customToolbar(title: String, navigationPath: Binding<NavigationPath>, showBackButton: Bool = true) -> some View {
        modifier(CustomToolbarModifier(navigationPath: navigationPath, title: title, showBackButton: showBackButton))
    }
}
