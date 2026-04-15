import SwiftUI
import FitnessResources
import FitnessUI

public struct ExerciseSeatPickerView: View {
    public var formViewModel: ExerciseFormViewModel
    @Binding public var isPresented: Bool
    public let onSave: () -> Void
    public let onCancel: () -> Void

    @State private var seatPart1: String = ""
    @State private var seatPart2: String = ""

    #if canImport(UIKit)
    @State private var keyboard = KeyboardObserver()
    #endif

    private let textColor: Color = AppStyle.Color.white

    private var hideChrome: Bool {
        #if canImport(UIKit)
        keyboard.isVisible
        #else
        false
        #endif
    }

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
        OverlaySheetContainer(
            isPresented: $isPresented,
            onCancel: onCancel,
            actions: {
                if !hideChrome {
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
            },
            content: {
                Text(L10n.cardEditSeatTitle)
                    .font(AppStyle.Font.sheetTitle)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, AppStyle.Padding.sectionSpacing)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Seat Settings")
                        .font(AppStyle.Font.sheetSectionLabel)
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
                .padding(.bottom, 20)
            }
        )
        .onAppear { loadSeatParts() }
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
