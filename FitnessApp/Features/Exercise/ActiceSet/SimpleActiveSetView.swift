import SwiftUI

struct SimpleActiveSetView: View {
    let exercise: Exercise
    @Binding var setProgress: [SetProgress]
    @ObservedObject var viewModel: ActiveSetViewModel
    
    private let iconSize: CGFloat = 26
    
    // Responsive spacing wie in ActiveCardView
    private var dynamicSpacing: CGFloat {
        UIScreen.main.bounds.width > 390 ? 8 : 6
    }
    
    private var dynamicPadding: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        if screenWidth > 400 { return 8 }  // iPhone 16 Pro: minimal padding
        else if screenWidth > 375 { return 6 }  // iPhone 14/15: tight
        else { return 4 }  // iPhone 12/13 mini: ultra tight
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Quick Done Mode
            if viewModel.quickDoneModeActive {
                ForEach(setProgress.indices, id: \.self) { index in
                    let progress = setProgress[index]
                    createQuickDoneRow(index: index, progress: progress)
                }
            }
            // Normal Mode
            else {
                ForEach(setProgress.indices, id: \.self) { index in
                    let progress = setProgress[index]
                    createNormalRow(index: index, progress: progress)
                }
            }
        }
        .padding(.horizontal, dynamicPadding)
        .padding(.vertical, 12)
        .background(
            Group {
                if #available(iOS 26.0, *) {
                    Color.clear
                        .glassEffect(in: .rect(cornerRadius: AppStyle.CornerRadius.card))
                } else if #available(iOS 18.0, *) {
                    LiquidGlassBackground(
                        cornerRadius: AppStyle.CornerRadius.card,
                        material: .ultraThinMaterial,
                        tintOpacity: 0.0,
                        showsEdgeStroke: false,
                        showsCaustic: false,
                        shadowOpacity: 0.0,
                        lightnessBoostOpacity: 0.0
                    )
                } else {
                    AppStyle.Color.exerciseCardBackground.opacity(0.85)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous))
        .padding(.horizontal, 0) // No extra padding - handled by parent
        .onChange(of: viewModel.pendingSetIndex) { index in
            if let index = index {
                viewModel.processQuickDone(at: index)
                viewModel.pendingSetIndex = nil
            }
        }
    }
    
    @ViewBuilder
    private func createQuickDoneRow(index: Int, progress: SetProgress) -> some View {
        HStack(spacing: dynamicSpacing) {
            // Nummer
            ZStack {
                Circle()
                    .fill(AppStyle.Color.backgroundColor)
                    .frame(width: iconSize, height: iconSize)
                
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppStyle.Color.white)
            }
            .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.3)
            
            if exercise.hasWeight {
                Button(WeightFormatter.displayWeight(progress.weight)) {
                    if progress.status != .notStarted && progress.status != .inProgress {
                        viewModel.startEditingSet(index: index, mode: .edit)
                    }
                }
                .font(AppStyle.Font.tileLabel)
                .foregroundColor(AppStyle.Color.white)
                .frame(minWidth: UIScreen.main.bounds.width <= 390 ? 50 : 60, minHeight: 24)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppStyle.Color.metricChipBackground)
                .cornerRadius(AppStyle.CornerRadius.defaultButton)
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton)
                        .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
                )
                .buttonStyle(PlainButtonStyle())
                .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.3)
            }

            Button(progress.status != .notStarted && progress.status != .inProgress ? "\(progress.currentReps)" : "") {
                viewModel.startEditingSet(index: index, mode: .edit)
            }
            .font(AppStyle.Font.tileLabel)
            .foregroundColor(AppStyle.Color.white)
            .frame(minWidth: exercise.hasWeight ? 35 : (UIScreen.main.bounds.width <= 390 ? 110 : 120), minHeight: 24)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppStyle.Color.metricChipBackground)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton)
                    .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
            )
            .buttonStyle(PlainButtonStyle())
            .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.3)
            .accessibilityIdentifier("id_reps_set_\(index)")

            Text("of \(exercise.reps)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: true, vertical: false)
                .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.3)

            if progress.status == .notStarted || progress.status == .inProgress {
                Button("Done") {
                    viewModel.pendingSetIndex = index
                }
                .font(AppStyle.Font.regularChip)
                .foregroundColor(AppStyle.Color.white)
                .frame(width: 80, height: 28)
                .background(AppStyle.Color.primaryButton)
                .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
                .buttonStyle(PlainButtonStyle())
                .disabled(progress.status == .completedDone || viewModel.isLastSetCompleted)
                .accessibilityIdentifier("id_button_quick_done_set_\(index)")
            }
        }
        .padding(.horizontal, dynamicPadding)
    }
    
    @ViewBuilder
    private func createNormalRow(index: Int, progress: SetProgress) -> some View {
        HStack(spacing: dynamicSpacing) {
            // Nummer mit optionalem Glow für aktives Set
            ZStack {
                Circle()
                    .fill(AppStyle.Color.backgroundColor)
                    .frame(width: iconSize, height: iconSize)
                
                if index == viewModel.activeSetIndex && !viewModel.quickDoneAllCompleted {
                    Circle()
                        .stroke(AppStyle.Color.greenGlow, lineWidth: 2)
                        .frame(width: iconSize, height: iconSize)
                }
                
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppStyle.Color.white)
            }
            .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.3)
            
            if exercise.hasWeight {
                Button(WeightFormatter.displayWeight(progress.weight)) {
                    if progress.status != .notStarted && progress.status != .inProgress {
                        viewModel.startEditingSet(index: index, mode: .edit)
                    }
                }
                .font(AppStyle.Font.tileLabel)
                .foregroundColor(AppStyle.Color.white)
                .frame(minWidth: UIScreen.main.bounds.width <= 390 ? 50 : 60, minHeight: 24)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppStyle.Color.metricChipBackground)
                .cornerRadius(AppStyle.CornerRadius.defaultButton)
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton)
                        .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
                )
                .buttonStyle(PlainButtonStyle())
                .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.3)
            }

            Button(progress.status != .notStarted && progress.status != .inProgress ? "\(progress.currentReps)" : "") {
                viewModel.startEditingSet(index: index, mode: .edit)
            }
            .font(AppStyle.Font.tileLabel)
            .foregroundColor(AppStyle.Color.white)
            .frame(minWidth: exercise.hasWeight ? 35 : (UIScreen.main.bounds.width <= 390 ? 110 : 120), minHeight: 24)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppStyle.Color.metricChipBackground)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton)
                    .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
            )
            .buttonStyle(PlainButtonStyle())
            .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.3)
            .accessibilityIdentifier("id_reps_set_\(index)")

            Text("of \(exercise.reps)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: true, vertical: false)
                .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.3)
        }
        .padding(.horizontal, dynamicPadding)
    }
}
