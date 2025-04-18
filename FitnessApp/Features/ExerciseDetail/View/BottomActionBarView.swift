import SwiftUI

struct BottomActionBarView: View {
    let viewModel: BottomActionBarViewModel
    let onStart: () -> Void
    let onCompleteSet: () -> Void
    let onReset: () -> Void
    let onEditLess: () -> Void
    let onEditMore: () -> Void
    
    var body: some View {
        HStack {
                    Spacer()

                    if viewModel.showSetControls {
                        HStack(spacing: 8) {
                            Button("Less", action: onEditLess)
                                .modifier(actionStyle(.dark))
                            Button("Done!", action: onCompleteSet)
                                .modifier(actionStyle(.light))
                            Button("More", action: onEditMore)
                                .modifier(actionStyle(.dark))
                        }
                    } else if viewModel.showStartButton {
                        Button(viewModel.startTitle, action: onStart)
                            .modifier(actionStyle(.dark, wide: true))
                    } else if viewModel.showResetProgress {
                        Button("Reset Progress", action: onReset)
                            .modifier(actionStyle(.dark, wide: true))
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(
                    Rectangle()
                        .fill(Color.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
                )
            }
    
    private func actionStyle(_ type: ActionType, wide: Bool = false) -> some ViewModifier {
        ActionButtonModifier(type: type, wide: wide)
    }
    
    enum ActionType {
        case dark, light
    }
    
    struct ActionButtonModifier: ViewModifier {
        let type: ActionType
        let wide: Bool
        
        func body(content: Content) -> some View {
            content
                .fontWeight(.semibold)
                .foregroundColor(type == .dark ? AppStyle.Color.white : AppStyle.Color.purpleDark)
                .padding(.horizontal, wide ? 32 : 20)
                .padding(.vertical, 12)
                .background(type == .dark ? AppStyle.Color.purpleDark : AppStyle.Color.white)
                .clipShape(Capsule())
        }
    }
}
