import SwiftUI

struct ActiveSetView: View {
    let sets: Int
    let exercise: Exercise
    @Binding var setProgress: [SetProgress]
    @ObservedObject var viewModel: ActiveSetViewModel
    
    private let backgroundColor = AppStyle.Color.activeSetBackground
    private let iconSize: CGFloat = 26
    private let defaultPadding: CGFloat = AppStyle.Padding.horizontal
    private let chipModifiedColor = Color(hex: "#051920")
    private let chipModifiedBorderColor = Color(hex: "#014F55")
    
    var body: some View {
        CardBackground(useGlassEffect: true) {
            VStack(alignment: .leading, spacing: 6) {
                // Quick Done Mode
                if viewModel.quickDoneModeActive {
                    ForEach(setProgress.indices, id: \.self) { index in
                        let progress = setProgress[index]
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppStyle.Color.backgroundColor)
                                    .frame(width: iconSize, height: iconSize)
                                
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppStyle.Color.white)
                            }
                            .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.4)
                            
                            Button("\(progress.weight == floor(progress.weight) ? "\(Int(progress.weight))" : String(progress.weight).replacingOccurrences(of: ".", with: ",")) kg") {
                                // Nur klickbar wenn Set abgeschlossen ist
                                if progress.status != .notStarted && progress.status != .inProgress {
                                    viewModel.startEditingSet(index: index, mode: .edit)
                                }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppStyle.Color.white)
                            .frame(minWidth: 60, minHeight: 24)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(abs(progress.weight - exercise.weight) > 0.0001 ? chipModifiedColor : AppStyle.Color.gray.opacity(0.7))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(abs(progress.weight - exercise.weight) > 0.0001 ? chipModifiedBorderColor : Color.clear, lineWidth: 1.5)
                            )
                            .buttonStyle(PlainButtonStyle())
                            .contentShape(Rectangle())
                            .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.4)
                            
                            
                            HStack(spacing: 8) {
                                // Chip immer sichtbar - leer wenn noch nicht done
                                Button(progress.status != .notStarted && progress.status != .inProgress ? "\(progress.currentReps)" : "") {
                                    viewModel.startEditingSet(index: index, mode: .edit)
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppStyle.Color.white)
                                .frame(minWidth: 36, minHeight: 24)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill((progress.status != .notStarted && progress.status != .inProgress && progress.currentReps != exercise.reps) ? chipModifiedColor : AppStyle.Color.gray.opacity(0.7))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke((progress.status != .notStarted && progress.status != .inProgress && progress.currentReps != exercise.reps) ? chipModifiedBorderColor : Color.clear, lineWidth: 1.5)
                                )
                                .buttonStyle(PlainButtonStyle())
                                .contentShape(Rectangle())
                                .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.4)
                                
                                Text(" of ")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppStyle.Color.white)
                                    .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.4)
                                
                                Text("\(exercise.reps)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppStyle.Color.white)
                                    .opacity((index == viewModel.activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.4)
                                
                                if progress.status == .notStarted || progress.status == .inProgress {
                                    Button(action: {
                                        viewModel.pendingSetIndex = index
                                    }) {
                                        Text("Done")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppStyle.Color.white)
                                            .frame(width: 80, height: 28)
                                            .background(AppStyle.Color.primaryButton)
                                            .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
                                    }
                                    .contentShape(Rectangle())
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(progress.status == .completedDone || viewModel.isLastSetCompleted)
                                }
                                
                                Spacer()
                            }
                            
                            if progress.status != .notStarted && progress.status != .inProgress {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: iconSize, height: iconSize)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, AppStyle.Color.green)
                            }
                        }
                    }
                }
                
                // Normal Mode
                else {
                    ForEach(Array(setProgress.enumerated()), id: \.offset) { index, progress in
                        ActiveSetRowView(
                            index: index,
                            progress: progress,
                            exercise: exercise,
                            activeSetIndex: viewModel.activeSetIndex,
                            iconSize: iconSize,
                            quickDoneAllCompleted: viewModel.quickDoneAllCompleted,
                            chipModifiedColor: chipModifiedColor,
                            chipModifiedBorderColor: chipModifiedBorderColor,
                            onEdit: {
                                viewModel.startEditingSet(index: index, mode: .edit)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 6)
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .cornerRadius(AppStyle.CornerRadius.card)
        .onChange(of: viewModel.pendingSetIndex) { index in
            if let index = index {
                viewModel.processQuickDone(at: index)
                viewModel.pendingSetIndex = nil
            }
        }
    }
}

private struct ActiveSetRowView: View {
    let index: Int
    let progress: SetProgress
    let exercise: Exercise
    let activeSetIndex: Int
    let iconSize: CGFloat
    let quickDoneAllCompleted: Bool
    let chipModifiedColor: Color
    let chipModifiedBorderColor: Color
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppStyle.Color.backgroundColor)
                    .frame(width: iconSize, height: iconSize)
                
                if index == activeSetIndex && !quickDoneAllCompleted {
                    Circle()
                        .stroke(AppStyle.Color.greenGlow, lineWidth: 2)
                        .frame(width: iconSize, height: iconSize)
                }
                
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppStyle.Color.white)
            }
            .opacity((index == activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.4)
            
            Button("\(progress.weight == floor(progress.weight) ? "\(Int(progress.weight))" : String(progress.weight).replacingOccurrences(of: ".", with: ",")) kg") {
                // Nur klickbar wenn Set abgeschlossen ist
                if progress.status != .notStarted && progress.status != .inProgress {
                    onEdit()
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(AppStyle.Color.white)
            .frame(minWidth: 60, minHeight: 24)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(abs(progress.weight - exercise.weight) > 0.0001 ? chipModifiedColor : AppStyle.Color.gray.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                            .stroke(abs(progress.weight - exercise.weight) > 0.0001 ? chipModifiedBorderColor : Color.clear, lineWidth: 1.5)
            )
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            .opacity((index == activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.4)

            
            
            HStack(spacing: 8) {
                // Chip immer sichtbar - leer wenn noch nicht done
                Button(progress.status != .notStarted && progress.status != .inProgress ? "\(progress.currentReps)" : "") {
                    onEdit()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppStyle.Color.white)
                .frame(minWidth: 36, minHeight: 24)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill((progress.status != .notStarted && progress.status != .inProgress && progress.currentReps != exercise.reps) ? chipModifiedColor : AppStyle.Color.gray.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((progress.status != .notStarted && progress.status != .inProgress && progress.currentReps != exercise.reps) ? chipModifiedBorderColor : Color.clear, lineWidth: 1.5)
                )
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
                .opacity((index == activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.4)
                
                Text(" of ")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppStyle.Color.white)
                    .opacity((index == activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.4)
                
                Text("\(exercise.reps)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppStyle.Color.white)
                    .opacity((index == activeSetIndex || progress.status != .notStarted && progress.status != .inProgress) ? 1.0 : 0.4)
                
                Spacer()
            }
        }
    }
}

// MARK: - Reusable ActiveSetChip Component
private struct ActiveSetChip: View {
    let text: String
    let textColor: Color
    let minWidth: CGFloat
    let isDashed: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(text) {
            onTap()
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(textColor)
        .frame(minWidth: minWidth, minHeight: 24)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppStyle.Color.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    AppStyle.Color.gray.opacity(0.7),
                    style: StrokeStyle(
                        lineWidth: 1,
                        dash: isDashed ? [4, 4] : []
                    )
                )
        )
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}
