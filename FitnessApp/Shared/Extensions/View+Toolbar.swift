import SwiftUI

extension View {
    /// Applies standard toolbar styling with consistent title appearance
    /// - Parameter title: The title to display in the toolbar
    /// - Returns: View with applied toolbar styling
    func standardToolbar(title: String) -> some View {
        self
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(AppStyle.Font.navigationHeadline)
                        .foregroundColor(AppStyle.Color.white)
                }
            }
    }
}
