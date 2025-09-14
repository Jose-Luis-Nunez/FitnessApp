import SwiftUI
import SwiftUI

struct ActiveSetView: View {
    let sets: Int
    let exercise: Exercise
    @Binding var setProgress: [SetProgress]
    @ObservedObject var viewModel: ActiveSetViewModel
    
    private let backgroundColor = AppStyle.Color.activeSetBackground
    private let iconSize: CGFloat = 26
    private let defaultPadding: CGFloat = AppStyle.Padding.horizontal
    
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
                            
                            Text("\(progress.weight == floor(progress.weight) ? "\(Int(progress.weight))" : String(progress.weight).replacingOccurrences(of: ".", with: ",")) kg")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(abs(progress.weight - exercise.weight) > 0.0001 ? AppStyle.Color.green : AppStyle.Color.white)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                if progress.status != .notStarted && progress.status != .inProgress {
                                    Button("\(progress.currentReps)") {
                                        viewModel.startEditingSet(index: index, mode: .edit)
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppStyle.Color.green)
                                    .buttonStyle(PlainButtonStyle())
                                    .contentShape(Rectangle())
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 16, height: 16)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(AppStyle.Color.green)
                                }
                                
                                Text(" of ")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppStyle.Color.white)
                                
                                Text("\(exercise.reps)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppStyle.Color.white)
                                
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
            
            Text("\(progress.weight == floor(progress.weight) ? "\(Int(progress.weight))" : String(progress.weight).replacingOccurrences(of: ".", with: ",")) kg")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(abs(progress.weight - exercise.weight) > 0.0001 ? AppStyle.Color.green : AppStyle.Color.white)

            
            Spacer()
            
            HStack(spacing: 4) {
                if progress.status != .notStarted && progress.status != .inProgress {
                    Button("\(progress.currentReps)") {
                        onEdit()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppStyle.Color.green)
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppStyle.Color.green)
                }
                
                Text(" of ")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppStyle.Color.white)
                
                Text("\(exercise.reps)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppStyle.Color.white)
                
                Spacer()
            }
        }
    }
}
