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
                            navigationPath.removeLast()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(AppStyle.Color.white)
                                .imageScale(.large)
                        }
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
