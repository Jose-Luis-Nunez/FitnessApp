import SwiftUI
import FitnessUI

struct AddFriendSheet: View {
    @Binding var isPresented: Bool
    @State private var viewModel: AddFriendViewModel
    @FocusState private var nameFieldFocused: Bool

    init(isPresented: Binding<Bool>, initialJSON: String? = nil, fileName: String? = nil, onAdded: @escaping () -> Void) {
        _isPresented = isPresented
        _viewModel = State(initialValue: AddFriendViewModel(
            initialJSON: initialJSON,
            fileName: fileName,
            onAdded: onAdded,
            onDismiss: { isPresented.wrappedValue = false }
        ))
    }

    private var detentHeight: CGFloat {
        var h: CGFloat = 260
        if viewModel.hasData { h += 72 }
        if viewModel.errorMessage != nil { h += 36 }
        return h
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppStyle.Padding.sectionSpacing) {
                Text("Add Friend")
                    .font(AppStyle.Font.sheetTitle)
                    .foregroundColor(AppStyle.Color.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, AppStyle.Padding.sectionSpacing)

                TextField("Name", text: $viewModel.friendName)
                    .font(AppStyle.Font.tileValue)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(AppStyle.Layout.profileInputPadding)
                    .background(AppStyle.Color.sheetInputBackground)
                    .cornerRadius(AppStyle.CornerRadius.card)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { nameFieldFocused = false }
                    .accessibilityIdentifier("id_friends_add_name_input")

                if viewModel.hasData {
                    dataReceivedTile
                }

                if let msg = viewModel.errorMessage {
                    Text(msg)
                        .font(AppStyle.Font.profileCardTitle)
                        .foregroundColor(AppStyle.Color.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.top, AppStyle.Padding.sectionSpacing)
            .padding(.bottom, AppStyle.Padding.sectionSpacing)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !nameFieldFocused {
                ExercisePickerActionButtons(
                    cancelLabel: "Cancel",
                    saveLabel: "Save",
                    saveDisabled: viewModel.isSaveDisabled,
                    onCancel: { isPresented = false },
                    onSave: { viewModel.saveTapped() }
                )
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.top, AppStyle.Padding.sectionSpacing)
                .background(AppStyle.Color.backgroundColor)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: nameFieldFocused)
        .preferredColorScheme(.dark)
        .presentationBackground(AppStyle.Color.backgroundColor)
        .presentationDetents([.height(detentHeight)])
        .presentationDragIndicator(.visible)
        .task {
            try? await Task.sleep(for: .milliseconds(600))
            nameFieldFocused = true
        }
    }

    private var dataReceivedTile: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.fileName ?? "Training data")
                    .font(AppStyle.Font.cardSmallBold)
                    .foregroundColor(AppStyle.Color.white)
                    .lineLimit(1)
                Text("Training data received")
                    .font(AppStyle.Font.detailCaption)
                    .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.overlayBackdrop))
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton)
                .fill(AppStyle.Color.green.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton)
                        .stroke(AppStyle.Color.green, lineWidth: 2)
                )
        )
    }
}
