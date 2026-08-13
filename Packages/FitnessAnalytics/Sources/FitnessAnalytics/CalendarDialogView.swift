import FitnessUI
import Foundation
import SwiftUI

public struct CalendarDialogView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Binding public var isPresented: Bool
    @Binding public var selectedDate: Date
    @State private var tempDate: Date
    public let highlightedDates: [Date]
    public let title: String
    public let locale: Locale

    public init(
        isPresented: Binding<Bool>,
        selectedDate: Binding<Date>,
        highlightedDates: [Date] = [],
        title: String = "Training Calendar",
        locale: Locale = Locale(identifier: "de_DE")
    ) {
        self._isPresented = isPresented
        self._selectedDate = selectedDate
        self._tempDate = State(wrappedValue: selectedDate.wrappedValue)
        self.highlightedDates = highlightedDates
        self.title = title
        self.locale = locale
    }

    public var body: some View {
        Group {
            if isPresented {
                ZStack {
                    Color.black.opacity(0.5)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isPresented = false
                        }

                    VStack {
                        Spacer()

                        VStack(spacing: 16) {
                            VStack {
                                Text(title)
                                    .font(.headline)
                                    .foregroundColor(AppStyle.Color.white)
                                    .padding(.top, 12)
                                    .padding(.horizontal, 16)

                                Spacer().frame(height: 20)

                                CalendarGridView(
                                    selectedDate: $tempDate,
                                    highlightedDates: highlightedDates,
                                    locale: locale
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal)

                                actionButtons
                            }
                            .background(appColorTheme.accent.black)
                            .cornerRadius(AppStyle.CornerRadius.defaultButton)
                            .padding(16)
                        }
                        .frame(maxWidth: 400, maxHeight: 250)

                        Spacer()
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                isPresented = false
            }
            .font(.body)
            .foregroundColor(AppStyle.Color.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)

            Button("Select") {
                selectedDate = tempDate
                isPresented = false
            }
            .font(.body)
            .foregroundColor(AppStyle.Color.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(appColorTheme.accent.primary)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
}
