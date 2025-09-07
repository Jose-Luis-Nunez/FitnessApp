import SwiftUI

struct IdleActiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    @ObservedObject var analyticsViewModel: AnalyticsViewModel

    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    let onStart: ((Exercise) -> Void)?

    @State private var isShowingAnalytics = false

    private let chipHeight: CGFloat = 32

    var body: some View {
        CardBackground(backgroundColor: AppStyle.Color.exerciseCardBackground, useGlassEffect: true, addPadding: true) {
            HStack(alignment: .center, spacing: 8) {
                // Left area: Category Icon
                categoryIconView
                
                // Middle area: Title and chips (Takes remaining space)
                VStack(alignment: .leading, spacing: 8) {
                    // Level 1: Exercise title
                    Text(viewModel.exercise.name)
                        .font(AppStyle.Font.cardHeadline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            if isEditable {
                                onEdit(viewModel.exercise)
                            }
                        }
                    
                    // Level 2: Sets chip, Weight chip, and Analytics icon
                    HStack(alignment: .center, spacing: 6) {
                        // Sets chip
                        AppChip(
                            text: viewModel.exercise.seatSetting ?? L10n.seatChipDefaultvalue,
                            fontColor: AppStyle.Color.white,
                            backgroundColor: AppStyle.Color.exerciseCardBackground,
                            size: .regular,
                            icon: ChipIcon(image: "chairSettings", color: .white, size: .large),
                            onTap: isEditable ? { onEdit(viewModel.exercise) } : nil,
                            borderColor: Color(hex: "#2B2B2B")
                        )
                        .frame(height: chipHeight)
                        
                        // Weight chip
                        AppChip(
                            text: "\(viewModel.exercise.weight == floor(viewModel.exercise.weight) ? "\(Int(viewModel.exercise.weight))" : String(viewModel.exercise.weight).replacingOccurrences(of: ".", with: ",")) kg",
                            fontColor: AppStyle.Color.white,
                            backgroundColor: AppStyle.Color.exerciseCardBackground,
                            size: .regular,
                            onTap: isEditable ? { onEdit(viewModel.exercise) } : nil,
                            borderColor: Color(hex: "#2B2B2B")
                        )
                        .frame(height: chipHeight)
                        
                        // Analytics chip
                        Button(action: { isShowingAnalytics = true }) {
                            HStack(spacing: 6) {
                                Image("analyticsEntry")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(AppStyle.Color.greenGlow)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .frame(height: chipHeight)
                            .background(AppStyle.Color.exerciseCardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#2B2B2B"), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity) // Takes remaining space intelligently
                
                // Right area: Start button
                if let onStart = onStart, !viewModel.exercise.isCompleted {
                    Button(action: { onStart(viewModel.exercise) }) {
                        ZStack {
                            Circle()
                                .fill(AppStyle.Color.green)
                                .frame(width: 36, height: 36)

                            Image(systemName: "play.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.white)
                                .offset(x: 2, y: 0)
                        }
                    }
                    .accessibilityIdentifier("id_button_start_exercise")
                    .buttonStyle(.plain)

                }
            }
            .sheet(isPresented: $isShowingAnalytics) {
                AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
            }
        }
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)

    }
    
    private var categoryIconView: some View {
        Image(viewModel.exercise.category.defaultIconName)
            .resizable()
            .scaledToFill()
            .frame(width: 64, height: 64, alignment: viewModel.exercise.category.iconAlignment)
            .clipped()
            .foregroundColor(AppStyle.Color.white)
    }
}
