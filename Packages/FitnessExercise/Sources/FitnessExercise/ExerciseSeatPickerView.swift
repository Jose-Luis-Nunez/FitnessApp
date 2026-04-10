import SwiftUI
import FitnessResources
import FitnessUI

public struct ExerciseSeatPickerView: View {
    @ObservedObject public var formViewModel: ExerciseFormViewModel
    @Binding public var isPresented: Bool
    public let onSave: () -> Void
    public let onCancel: () -> Void

    @State private var seatPart1: String = ""
    @State private var seatPart2: String = ""
    @State private var isContentVisible: Bool = false

    private let textColor: Color = AppStyle.Color.white

    public init(
        formViewModel: ExerciseFormViewModel,
        isPresented: Binding<Bool>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.formViewModel = formViewModel
        _isPresented = isPresented
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(AppStyle.Opacity.overlayBackdrop)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                    isPresented = false
                }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(AppStyle.Opacity.grabberHandle))
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                Text(L10n.cardEditSeatTitle)
                    .font(.title2)
                    .foregroundColor(textColor)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 18)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Seat Settings")
                        .font(.headline)
                        .foregroundColor(textColor)

                    HStack(spacing: 12) {
                        ExercisePickerInputField(prompt: "Setting 1", text: Binding(
                            get: { seatPart1 },
                            set: { newValue in
                                seatPart1 = newValue
                                updateSeat()
                            }
                        ))

                        ExercisePickerInputField(prompt: "Setting 2", text: Binding(
                            get: { seatPart2 },
                            set: { newValue in
                                seatPart2 = newValue
                                updateSeat()
                            }
                        ))
                    }
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.bottom, 20)

                ExercisePickerActionButtons(
                    saveDisabled: false,
                    onCancel: {
                        onCancel()
                        isPresented = false
                    },
                    onSave: {
                        onSave()
                        isPresented = false
                    }
                )
            }
            .exercisePickerSheet(isContentVisible: isContentVisible)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height > 80 {
                        onCancel()
                        isPresented = false
                    }
                }
            )
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            loadSeatParts()
            withAnimation(.easeOut(duration: 0.18)) { isContentVisible = true }
        }
        .onChange(of: isPresented) { newValue in
            if !newValue { isContentVisible = false }
        }
    }

    private func updateSeat() {
        formViewModel.seat = [seatPart1, seatPart2]
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    private func loadSeatParts() {
        let parts = formViewModel.seat.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        seatPart1 = parts.count > 0 ? String(parts[0]) : ""
        seatPart2 = parts.count > 1 ? String(parts[1]) : ""
    }
}
