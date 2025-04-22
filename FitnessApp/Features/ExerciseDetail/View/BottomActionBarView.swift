import SwiftUI

struct BottomActionBarView: View {
    let viewModel: BottomActionBarViewModel
    let onStart: () -> Void
    let onCompleteSet: () -> Void
    let onReset: () -> Void
    let onEditLess: () -> Void
    let onEditMore: () -> Void
    let onFinish: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 8) {
                if viewModel.showStartButton {
                    Button(action: onStart) {
                        Text(viewModel.startButtonTitle)
                            .font(AppStyle.Font.regularChip)
                            .foregroundColor(AppStyle.Color.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppStyle.Color.purpleGrey)
                            .cornerRadius(AppStyle.CornerRadius.card)
                    }
                }
                
                if viewModel.showSetControls {
                    Button(action: onEditLess) {
                        Text("Less")
                            .font(AppStyle.Font.regularChip)
                            .foregroundColor(AppStyle.Color.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppStyle.Color.purpleGrey)
                            .cornerRadius(AppStyle.CornerRadius.card)
                    }
                    
                    Button(action: onCompleteSet) {
                        Text("Done")
                            .font(AppStyle.Font.regularChip)
                            .foregroundColor(AppStyle.Color.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppStyle.Color.purpleGrey)
                            .cornerRadius(AppStyle.CornerRadius.card)
                    }
                    
                    Button(action: onEditMore) {
                        Text("More")
                            .font(AppStyle.Font.regularChip)
                            .foregroundColor(AppStyle.Color.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppStyle.Color.purpleGrey)
                            .cornerRadius(AppStyle.CornerRadius.card)
                    }
                }
                
                if viewModel.showResetProgress {
                    Button(action: onReset) {
                        Text("Reset Progress")
                            .font(AppStyle.Font.regularChip)
                            .foregroundColor(AppStyle.Color.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppStyle.Color.purpleGrey)
                            .cornerRadius(AppStyle.CornerRadius.card)
                    }
                }
                
                if viewModel.showFinishButton {
                    Button(action: onFinish) {
                        Text("Beenden")
                            .font(AppStyle.Font.regularChip)
                            .foregroundColor(AppStyle.Color.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppStyle.Color.purpleGrey)
                            .cornerRadius(AppStyle.CornerRadius.card)
                    }
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.bottom, AppStyle.Padding.vertical)
            .background(AppStyle.Color.purpleDark)
        }
        .frame(height: 80)
    }
}
