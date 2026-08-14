import FitnessResources
import FitnessUI
import Foundation
import SwiftUI

public struct CalendarDialogView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var environmentLocale
    @Binding public var isPresented: Bool
    @Binding public var selectedDate: Date
    @State private var tempDate: Date
    public let highlightedDates: [Date]
    public let title: LocalizedStringResource
    public let explicitLocale: Locale?

    public init(
        isPresented: Binding<Bool>,
        selectedDate: Binding<Date>,
        highlightedDates: [Date] = [],
        title: LocalizedStringResource = AppText.analyticsTrainingCalendar,
        locale: Locale? = nil
    ) {
        self._isPresented = isPresented
        self._selectedDate = selectedDate
        self._tempDate = State(wrappedValue: selectedDate.wrappedValue)
        self.highlightedDates = highlightedDates
        self.title = title
        self.explicitLocale = locale
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
                                    locale: explicitLocale ?? environmentLocale
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
            Button(AppText.actionCancel) {
                isPresented = false
            }
            .font(.body)
            .foregroundColor(AppStyle.Color.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)

            Button(AppText.actionSelect) {
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
