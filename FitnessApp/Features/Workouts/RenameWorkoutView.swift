import SwiftUI

struct RenameWorkoutView: View {
    @Binding var workoutName: String
    @Binding var isPresented: Bool
    let workoutToRename: Workout
    let onSave: () -> Void
    
    private let textColor = AppStyle.Color.white
    
    var body: some View {
        ZStack {
            AppStyle.Color.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                dragIndicator
                headerView
                contentView
                Spacer()
                saveButtonView
            }
        }
    }
    
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(AppStyle.Color.gray.opacity(0.4))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 8)
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                isPresented = false
            }) {
                ZStack {
                    Circle()
                        .fill(AppStyle.Color.gray.opacity(0.15))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(AppStyle.Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppStyle.Color.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 16)
            
            Spacer()
            
            Text("Workout umbenennen")
                .font(AppStyle.Font.navigationHeadline)
                .foregroundColor(AppStyle.Color.white)
            
            Spacer()
            
            // Invisible button for balance
            Button(action: {}) {
                Image(systemName: "xmark")
                    .foregroundColor(AppStyle.Color.white)
                    .imageScale(.large)
            }
            .opacity(0)
            .padding(.trailing, 16)
        }
        .padding(.vertical, 16)
        .background(AppStyle.Color.backgroundColor)
    }
    
    private var contentView: some View {
        VStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.headline)
                    .foregroundColor(textColor)
                
                Text("Set your workout name")
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.7))
                
                HStack {
                    TextField("Workout Name", text: $workoutName)
                        .foregroundColor(textColor)
                    
                    if !workoutName.isEmpty {
                        Button(action: {
                            workoutName = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppStyle.Color.gray)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(12)
                .background(AppStyle.Color.backgroundColor)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppStyle.Color.gray, lineWidth: 1)
                )
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
        }
        .padding(.top, 32)
    }
    
    private var saveButtonView: some View {
        VStack(spacing: 16) {
            Button(action: {
                onSave()
                isPresented = false
            }) {
                Text("Save")
                    .font(AppStyle.Font.defaultFont)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                        AppStyle.Color.gray : AppStyle.Color.green
                    )
                    .cornerRadius(12)
            }
            .disabled(workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.bottom, safeAreaInset + 16)
        }
    }
    
    private var safeAreaInset: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }
} 