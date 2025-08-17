import SwiftUI

struct WorkoutDropdownView: View {
    @ObservedObject var viewModel: MuscleCategorySelectionViewModel
    @EnvironmentObject private var overlayState: UIOverlayState
    
    private let storageService = WorkoutStorageService.shared
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                overlayState.showWorkoutDropdown.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Text(viewModel.currentWorkoutName)
                    .font(AppStyle.Font.navigationHeadline)
                    .foregroundColor(AppStyle.Color.white)
                    .lineLimit(1)
                
                Image(systemName: "chevron.down")
                    .foregroundColor(AppStyle.Color.white)
                    .rotationEffect(.degrees(overlayState.showWorkoutDropdown ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: overlayState.showWorkoutDropdown)
            }
        }
    }

}

#Preview {
    // Preview wrapper
    struct PreviewWrapper: View {
        @StateObject private var viewModel = MuscleCategorySelectionViewModel()
        @StateObject private var overlayState = UIOverlayState()
        
        var body: some View {
            ZStack {
                AppStyle.Color.backgroundColor.ignoresSafeArea()
                
                VStack {
                    WorkoutDropdownView(viewModel: viewModel)
                        .environmentObject(overlayState)
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    return PreviewWrapper()
}
