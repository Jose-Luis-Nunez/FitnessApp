import SwiftUI
import FitnessResources

extension View {
    public func standardToolbar(title: LocalizedStringResource) -> some View {
#if os(iOS)
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
#else
        self
            .navigationTitle(Text(title))
#endif
    }
}
