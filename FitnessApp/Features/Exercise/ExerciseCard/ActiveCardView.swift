import SwiftUI

struct ActiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise, ExerciseEditMode) -> Void
    let isEditable: Bool
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    let onStart: ((Exercise) -> Void)?
    let onReset: ((Exercise) -> Void)?
    let isActiveSetVisible: Bool
    let isResetEnabled: Bool
    
    @State private var isShowingAnalytics = false
    private let chipHeight: CGFloat = 32
    
    // Pro Max specific sizing
    private var isProMax: Bool {
        UIScreen.main.bounds.width >= 430 // iPhone 16 Pro Max threshold
    }
    
    private var analyticsButtonWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        if isProMax { return 80 }              // Pro Max: balanced
        else if screenWidth <= 375 { return 62 } // iPhone 12 mini: small but readable
        else if screenWidth <= 390 { return 65 } // iPhone 12: small but readable  
        else { return 70 }                    // iPhone 16 Pro: balanced
    }
    
    private var iconContainerWidth: CGFloat {
        isProMax ? 82 : 72
    }
    
    private var iconSize: CGFloat {
        isProMax ? 108 : 98
    }
    
    private var chipWidthVertical: CGFloat {
        isProMax ? 71 : 63
    }
    
    private var formattedWeight: String {
        let weight = viewModel.exercise.weight
        if weight == floor(weight) {
            return "\(Int(weight)) kg"
        } else {
            return "\(weight)".replacingOccurrences(of: ".", with: ",") + " kg"
        }
    }
    
    var body: some View {
        CardBackground(useGlassEffect: true, addPadding: true) {
            cardContentView
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
        }
    }
    
    private var cardContentView: some View {
        // Use fixed dimensions with responsive logic
        let dynamicSpacing: CGFloat = UIScreen.main.bounds.width > 390 ? 8 : 6
        let screenWidth = UIScreen.main.bounds.width
        let availableWidth = screenWidth - 64 // Account for card and outer padding
        
        // Responsive spacing between analytics and icon
        let analyticsToIconSpacing: CGFloat = {
            if isProMax { return 12 }  // iPhone 16 Pro Max: more generous spacing
            else if screenWidth > 400 { return 8 }  // iPhone 16 Pro: minimal spacing
            else if screenWidth > 375 { return 6 }  // iPhone 14/15: very tight
            else { return 4 }  // iPhone 12/13 mini: ultra tight
        }()
        
        let contentView = HStack(alignment: .center, spacing: dynamicSpacing) {
            exerciseInfoSection(availableWidth: availableWidth, dynamicSpacing: dynamicSpacing)
            
            Spacer()
                .frame(maxWidth: analyticsToIconSpacing)
            
            exerciseIconSection
        }
        .frame(height: 100)
        
        // Pro Max: Limit content width and center it
        if isProMax {
            return AnyView(
                contentView
                    .frame(maxWidth: 400) // Limit content width on Pro Max
                    .frame(maxWidth: .infinity) // Center it
            )
        } else {
            return AnyView(
                contentView
                    .frame(maxWidth: .infinity)
            )
        }
    }
    
    private func exerciseInfoSection(availableWidth: CGFloat, dynamicSpacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            exerciseTitle
            exerciseChipsSection(availableWidth: availableWidth, dynamicSpacing: dynamicSpacing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var exerciseTitle: some View {
        Text(viewModel.exercise.name)
            .font(AppStyle.Font.cardHeadline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func exerciseChipsSection(availableWidth: CGFloat, dynamicSpacing: CGFloat) -> some View {
        Group {
            if viewModel.exercise.hasWeight {
                HStack(alignment: .bottom, spacing: 6) {
                    VStack(alignment: .leading, spacing: 4) {
                        setsChip
                        repsChip
                    }
                    weightChip
                    analyticsButton
                }
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(AppStyle.Color.yellow)
                            .font(.system(size: 20, weight: .semibold))
                        Text("\(viewModel.exercise.sets)x")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppStyle.Color.white)
                    }
                    .frame(width: analyticsButtonWidth, height: 68)
                    .background(Color(hex: "#100F15"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
                    )

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(AppStyle.Color.green)
                            .font(.system(size: 20, weight: .semibold))
                        Text("\(viewModel.exercise.reps)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppStyle.Color.white)
                    }
                    .frame(width: analyticsButtonWidth, height: 68)
                    .background(Color(hex: "#100F15"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
                    )

                    analyticsButton
                }
            }
        }
    }
    
    private var setsChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .foregroundColor(AppStyle.Color.yellow)
                .font(.system(size: 14, weight: .semibold))
            
            Text("\(viewModel.exercise.sets)x")
                .font(AppStyle.Font.regularChip)
                .foregroundColor(AppStyle.Color.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(width: chipWidthVertical, height: chipHeight)
        .background(Color(hex: "#100F15"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
        )
    }
    
    private var repsChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(AppStyle.Color.green)
                .font(.system(size: 14, weight: .semibold))
            
            Text("\(viewModel.exercise.reps)")
                .font(AppStyle.Font.regularChip)
                .foregroundColor(AppStyle.Color.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(width: chipWidthVertical, height: chipHeight)
        .background(Color(hex: "#100F15"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
        )
    }
    
    private var weightChip: some View {
        Text(formattedWeight)
            .font(AppStyle.Font.regularChip)
            .foregroundColor(AppStyle.Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(height: 68) // Same height as analytics button (tall like analytics)
            .frame(width: analyticsButtonWidth) // Same width as analytics button
            .background(Color(hex: "#100F15"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
            )
    }
    
    private var analyticsButton: some View {
        Button(action: {
            isShowingAnalytics = true
        }) {
            Image("analyticsEntry")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60) // Larger icon size within the same chip
                .foregroundStyle(Color(hex:"#077484"))
                .frame(width: analyticsButtonWidth, height: 68) // Chip stays same size
                .background(Color(hex: "#100F15"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var exerciseIconSection: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(AppStyle.Color.greenBlack)
                    .frame(width: iconSize * 0.9, height: iconSize * 0.9)
                    .blur(radius: 12)
                    .opacity(0.5)
                
                Image(viewModel.exercise.displayIconName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: iconSize, height: iconSize, alignment: viewModel.exercise.iconAlignment)
                    .clipped()
            }
        }
        .frame(width: iconContainerWidth)
        .frame(maxHeight: .infinity)
    }
}
