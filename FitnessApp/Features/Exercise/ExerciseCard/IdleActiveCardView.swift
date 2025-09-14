import SwiftUI

struct IdleActiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    @ObservedObject var analyticsViewModel: AnalyticsViewModel

    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    let onStart: ((Exercise) -> Void)?

    @State private var isShowingAnalytics = false

    private let chipHeight: CGFloat = 36
    
    // Dynamischer Abstand basierend auf Screen-Breite
    private var dynamicSpacing: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        if screenWidth <= 375 { // iPhone SE, iPhone 12 mini
            return 4
        } else if screenWidth <= 390 { // iPhone 12, 13, 14
            return 8
        } else { // iPhone Pro Max
            return 12
        }
    }
    
    // Chip-Breite: nutzt verfügbaren Platz ohne Card zu verbreitern
    private var chipWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        if screenWidth <= 375 { // iPhone SE, iPhone 12 mini
            return 70
        } else if screenWidth <= 390 { // iPhone 12, 13, 14
            return 75
        } else { // iPhone Pro Max
            return 82
        }
    }

    var body: some View {
        CardBackground(backgroundColor: AppStyle.Color.exerciseCardBackground, useGlassEffect: true, addPadding: true) {
            HStack(alignment: .center, spacing: dynamicSpacing) {
                // Left area: Category Icon
                categoryIconView
                
                // Middle area: Title and chips (Takes remaining space)
                VStack(alignment: .leading, spacing: 8) {
                    // Level 1: Exercise title mit Play Button
                    HStack(alignment: .center) {
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
                        
                        // Play Button auf Titel-Höhe
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
                    
                    // Level 2: Sets chip, Weight chip, and Analytics icon
                    HStack(alignment: .center, spacing: 5) {
                        // Custom Sets chip (responsive width)
                        Button(action: {
                            if isEditable { onEdit(viewModel.exercise) }
                        }) {
                            HStack(spacing: 4) {
                                Image("chairSettings")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                    .foregroundColor(.white)
                                
                                Text(viewModel.exercise.seatSetting ?? L10n.seatChipDefaultvalue)
                                    .font(AppStyle.Font.regularChip)
                                    .foregroundColor(AppStyle.Color.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(width: chipWidth, height: chipHeight)
                            .background(Color.clear)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Custom Weight chip (responsive width)
                        Button(action: {
                            if isEditable { onEdit(viewModel.exercise) }
                        }) {
                            Text("\(viewModel.exercise.weight == floor(viewModel.exercise.weight) ? "\(Int(viewModel.exercise.weight))" : String(viewModel.exercise.weight).replacingOccurrences(of: ".", with: ",")) kg")
                                .font(AppStyle.Font.regularChip)
                                .foregroundColor(AppStyle.Color.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(width: chipWidth, height: chipHeight)
                                .background(Color.clear)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        // Analytics chip (responsive width)
                        Button(action: { isShowingAnalytics = true }) {
                            Image("analyticsEntry")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(AppStyle.Color.greenGlow)
                                .frame(width: chipWidth, height: chipHeight)
                                .background(Color.clear)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity) // Takes remaining space intelligently
            }
            .sheet(isPresented: $isShowingAnalytics) {
                AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
            }
        }
        .padding(.horizontal, AppStyle.Padding.card)
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
