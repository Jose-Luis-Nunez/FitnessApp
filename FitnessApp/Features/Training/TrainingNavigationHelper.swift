import SwiftUI

// MARK: - Training Start Source
enum TrainingStartSource {
    case categoryView           // Training started directly from CategoryView
    case categorySelectionView  // Training started from CategorySelectionView
}

// MARK: - Training Return Destination
enum TrainingReturnDestination {
    case categorySelectionView  // Normal return to CategorySelectionView
    case categoryView          // Return to CategoryView (when started from CategorySelectionView with active training)
}

// MARK: - Training Navigation Helper
struct TrainingNavigationHelper {
    
    /// Navigate to dedicated TrainingView
    static func navigateToTraining(
        exercise: Exercise,
        category: MuscleCategoryGroup,
        navigationPath: inout NavigationPath,
        returnDestination: TrainingReturnDestination = .categorySelectionView
    ) {
        navigationPath.append(NavigationDestination.training(exercise, category, returnDestination))
    }
    
    /// Create onStart closure that navigates to TrainingView
    static func createTrainingNavigation(
        category: MuscleCategoryGroup,
        navigationPath: Binding<NavigationPath>
    ) -> (Exercise) -> Void {
        return { exercise in
            var path = navigationPath.wrappedValue
            navigateToTraining(exercise: exercise, category: category, navigationPath: &path)
            navigationPath.wrappedValue = path
        }
    }
}

// MARK: - Training Button Component
struct TrainingNavigationButton: View {
    let exercise: Exercise
    let category: MuscleCategoryGroup
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        Button(action: {
            TrainingNavigationHelper.navigateToTraining(
                exercise: exercise,
                category: category,
                navigationPath: &navigationPath
            )
        }) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .foregroundColor(.white)
                Text("Training View")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppStyle.Color.green)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
