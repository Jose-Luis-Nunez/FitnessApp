import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: ActiveSetViewModel
    
    private let timerCircleSize: CGFloat = 200.0
    private let strokeWidth: CGFloat = 8.0
    private let buttonPadding: CGFloat = 10.0
    
    var body: some View {
        if viewModel.isSetInProgress && viewModel.timerSeconds > 0 {
            ZStack {
                Circle()
                    .stroke(AppStyle.Color.greenGlow, lineWidth: strokeWidth)
                    .frame(width: timerCircleSize, height: timerCircleSize)
                
                VStack(spacing: 8) {
                    Text(viewModel.formatTime(seconds: viewModel.timerSeconds))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(AppStyle.Color.white)
                    
                    Text("Satz \(viewModel.currentSet + 1)")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(AppStyle.Color.white)
                    
                    Button(action: {
                        viewModel.cancelActiveSet()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppStyle.Color.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppStyle.Color.exerciseCardBackground)
                            .cornerRadius(12)
                    }
                }
                .frame(width: timerCircleSize, height: timerCircleSize)
            }
            .padding(.vertical, 8)
            .background(AppStyle.Color.backgroundColor)
            
        } else {
            EmptyView()
        }
    }
}
