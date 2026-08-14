#if canImport(UIKit)
import UIKit
#endif
import FitnessUI
import SwiftUI
import FitnessResources

public enum NumberPadValueType {
    case integer, decimal
}

// MARK: - Input Mode State Machine

/// Single source of truth for how the user is currently interacting.
/// Eliminates the previous flag-wald (isFirstInput, isKeypadInput, isUserScrolling, isInitialized).
private enum InputMode: Equatable {
    case idle
    case typing
    case scrolling
}

// MARK: - Main View

public struct CustomNumberPadView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale
    public let currentValue: Double
    public let isWeight: Bool
    public let valueType: NumberPadValueType
    public let onValueChange: (Double) -> Void
    public let onDismiss: () -> Void

    @State private var inputValue: Double
    @State private var showComma: Bool = false
    @State private var shakeOffset: CGFloat = 0
    @State private var displayText: String = "0"
    @State private var inputMode: InputMode = .idle

    public init(
        currentValue: Double,
        isWeight: Bool,
        valueType: NumberPadValueType = .decimal,
        onValueChange: @escaping (Double) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.currentValue = currentValue
        self.isWeight = isWeight
        self.valueType = valueType
        self.onValueChange = onValueChange
        self.onDismiss = onDismiss

        _inputValue = State(wrappedValue: currentValue)
        _showComma = State(wrappedValue: currentValue != floor(currentValue))
        // The environment locale is unavailable during initialization. This
        // neutral seed is replaced with locale-aware text in `onAppear`.
        _displayText = State(wrappedValue: String(currentValue))
    }

    private var displayString: String {
        if valueType == .integer {
            return String(Int(inputValue))
        } else {
            if inputValue == floor(inputValue) && !showComma {
                return String(Int(inputValue))
            } else if inputValue == floor(inputValue) && showComma {
                return String(Int(inputValue)) + decimalSeparator
            } else {
                return WeightFormatter.format(inputValue, locale: locale)
            }
        }
    }

    private var decimalSeparator: String { locale.decimalSeparator ?? "." }

    private var statusText: String {
        guard inputValue >= 999.0 else {
            return isWeight ? "kg" : AppText.resolve(AppText.exerciseRepetitions, locale: locale)
        }
        return AppText.resolve(AppText.commonMaximumReached, locale: locale)
    }

    private var statusTextColor: Color {
        inputValue >= 999.0 ? appColorTheme.accent.primary : AppStyle.Color.white
    }

    public var body: some View {
        VStack(spacing: 0) {
            NumberScrollWheel(
                displayText: $displayText,
                inputValue: $inputValue,
                showComma: $showComma,
                inputMode: $inputMode,
                valueType: valueType,
                statusText: statusText,
                statusTextColor: statusTextColor,
                locale: locale,
                onAdjust: { delta in adjustValue(delta) }
            )

            NumberKeypad(
                valueType: valueType,
                decimalSeparator: decimalSeparator,
                onDigit: { appendDigit($0) },
                onComma: { appendComma() },
                onClear: { clearValue() },
                onDelete: { deleteLastDigit() },
                onCancel: { onDismiss() },
                onConfirm: {
                    onValueChange(inputValue)
                    onDismiss()
                }
            )
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: AppStyle.CornerRadius.pill,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: AppStyle.CornerRadius.pill,
                style: .continuous
            )
            .fill(AppStyle.Color.black)
            .ignoresSafeArea(.container, edges: .bottom)
        )
        .shadow(radius: AppStyle.CornerRadius.pill)
        .offset(x: shakeOffset)
        .onAppear {
            inputValue = currentValue
            showComma = currentValue != floor(currentValue)
            syncDisplayText()
            inputMode = .idle
        }
        .onChange(of: locale.identifier) { _, _ in
            syncDisplayText()
        }
    }

    // MARK: - State Mutations

    private func syncDisplayText() {
        displayText = displayString
    }

    private func appendDigit(_ digit: String) {
        if inputMode == .idle {
            inputMode = .typing
            inputValue = Double(digit) ?? 0.0
            showComma = false
            syncDisplayText()
            return
        }

        inputMode = .typing

        let currentString = displayText

        if valueType == .integer {
            if currentString.count < 3 {
                let newString = currentString == "0" ? digit : currentString + digit
                inputValue = Double(newString) ?? 0.0
            } else {
                inputValue = 999.0
                triggerMaximumFeedback()
            }
        } else {
            let parts = currentString.components(separatedBy: decimalSeparator)
            if parts.count == 1 {
                if parts[0].count < 3 {
                    let newString = currentString == "0" ? digit : currentString + digit
                    inputValue = Double(newString) ?? 0.0
                    showComma = false
                } else {
                    inputValue = 999.0
                    showComma = false
                    triggerMaximumFeedback()
                }
            } else {
                if parts[1].count < 2 {
                    let newString = currentString + digit
                    inputValue = WeightFormatter.parse(newString) ?? 0.0
                    showComma = false
                } else {
                    triggerMaximumFeedback()
                }
            }
        }
        syncDisplayText()
    }

    private func appendComma() {
        inputMode = .typing
        if valueType == .decimal {
            let currentString = displayText
            if !currentString.contains(decimalSeparator) && currentString != "0" {
                showComma = true
                syncDisplayText()
            }
        }
    }

    private func deleteLastDigit() {
        inputMode = .typing
        let currentString = displayText
        if currentString.count > 1 {
            var newString = String(currentString.dropLast())
            if newString.hasSuffix(decimalSeparator) {
                newString = String(newString.dropLast())
                showComma = false
            }
            inputValue = WeightFormatter.parse(newString) ?? 0.0
            showComma = newString.contains(decimalSeparator) || showComma
        } else {
            inputValue = 0.0
            showComma = false
        }
        syncDisplayText()
    }

    private func clearValue() {
        inputMode = .typing
        inputValue = 0.0
        showComma = false
        syncDisplayText()
    }

    private func adjustValue(_ delta: Int) {
        inputMode = .typing
        let newValue = max(0.0, min(999.0, inputValue + Double(delta)))

        if newValue == inputValue && delta > 0 {
            triggerMaximumFeedback()
        } else if newValue == inputValue && delta < 0 {
            hapticLight()
        } else {
            inputValue = newValue
            showComma = false
            syncDisplayText()
        }
    }

    // MARK: - Haptics

    private func hapticLight() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func triggerMaximumFeedback() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif

        withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
            shakeOffset = 10
        }
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(AppStyle.Animation.snapSpring) {
                shakeOffset = 0
            }
        }
    }
}

// MARK: - Number Scroll Wheel (extracted component)

/// Vertical scroll picker that shows values around the current input.
/// Only scrolls programmatically when the user interacts via the wheel itself or +/- buttons,
/// never when typing on the keypad.
private struct NumberScrollWheel: View {
    @Binding var displayText: String
    @Binding var inputValue: Double
    @Binding var showComma: Bool
    @Binding var inputMode: InputMode
    let valueType: NumberPadValueType
    let statusText: String
    let statusTextColor: Color
    let locale: Locale
    let onAdjust: (Int) -> Void

    private let pickerHeight: CGFloat = 120
    private let centerOffset: CGFloat = 15

    var body: some View {
        VStack(spacing: AppStyle.Layout.numberPadSpacing) {
            HStack {
                Button(action: { onAdjust(-1) }) {
                    Image(systemName: "minus")
                        .font(AppStyle.Font.numberPadSymbol)
                        .foregroundColor(AppStyle.Color.numberPadGray)
                        .frame(width: 50, height: 50)
                }

                Spacer()

                scrollContent

                Spacer()

                Button(action: { onAdjust(1) }) {
                    Image(systemName: "plus")
                        .font(AppStyle.Font.numberPadSymbol)
                        .foregroundColor(AppStyle.Color.numberPadGray)
                        .frame(width: 50, height: 50)
                }
            }
            .padding(.horizontal, AppStyle.Padding.card)

            Text(statusText)
                .font(AppStyle.Font.tileValue)
                .foregroundColor(statusTextColor)
                .animation(.easeInOut(duration: 0.3), value: statusText)
        }
        .padding(.vertical, AppStyle.Padding.card)
        .background(AppStyle.Color.sheetInputBackground.opacity(0.85))
    }

    private var scrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(pickerOptions, id: \.self) { option in
                        Text(option)
                            .font(option == displayText ? AppStyle.Font.numberPadSelectedValue : AppStyle.Font.numberPadSymbol)
                            .foregroundColor(AppStyle.Color.white)
                            .opacity(option == displayText ? 1.0 : AppStyle.Opacity.disabledElement)
                            .onTapGesture { selectOption(option, proxy: proxy) }
                            .background(scrollPositionTracker(for: option))
                            .id(option)
                    }
                }
                .padding(.vertical, AppStyle.Layout.scrollWheelItemHeight)
            }
            .coordinateSpace(name: "picker")
            .frame(height: pickerHeight)
            .clipped()
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in inputMode = .scrolling }
                    .onEnded { _ in snapAfterScroll(proxy: proxy) }
            )
            .onAppear { initialScroll(proxy: proxy) }
            .onChange(of: displayText) { _, newValue in
                guard inputMode == .scrolling else { return }
                scrollToValue(newValue, proxy: proxy)
            }
        }
    }

    // MARK: - Scroll Behavior

    private func initialScroll(proxy: ScrollViewProxy) {
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard inputMode == .idle else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(displayText, anchor: .center)
            }
        }
    }

    private func snapAfterScroll(proxy: ScrollViewProxy) {
        inputMode = .idle
        let target = displayText
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard inputMode != .typing else { return }
            withAnimation(AppStyle.Animation.snapSpring) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    private func scrollToValue(_ value: String, proxy: ScrollViewProxy) {
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard inputMode == .scrolling else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(value, anchor: .center)
            }
        }
    }

    private func selectOption(_ option: String, proxy: ScrollViewProxy) {
        guard let value = WeightFormatter.parse(option) else { return }
        inputMode = .idle
        inputValue = value
        let decimalSeparator = locale.decimalSeparator ?? "."
        showComma = option.contains(decimalSeparator) && option.hasSuffix(decimalSeparator)
        displayText = WeightFormatter.format(value, locale: locale)

        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(option, anchor: .center)
        }
    }

    // MARK: - Center Detection

    private func scrollPositionTracker(for option: String) -> some View {
        GeometryReader { geo in
            Color.clear
                .onChange(of: geo.frame(in: .named("picker")).midY) { _, _ in
                    guard inputMode == .scrolling else { return }
                    detectCentered(option: option, geometry: geo)
                }
        }
    }

    private func detectCentered(option: String, geometry: GeometryProxy) {
        let frame = geometry.frame(in: .named("picker"))
        let center = pickerHeight / 2 + centerOffset

        guard abs(frame.midY - center) < AppStyle.Layout.scrollWheelSnapTolerance, option != displayText else { return }
        guard let value = WeightFormatter.parse(option) else { return }

        inputValue = value
        let decimalSeparator = locale.decimalSeparator ?? "."
        showComma = option.contains(decimalSeparator) && option.hasSuffix(decimalSeparator)
        displayText = WeightFormatter.format(value, locale: locale)

        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    // MARK: - Picker Range

    private var pickerOptions: [String] {
        let currentInt = Int(inputValue)
        var options: [String] = []

        let start = max(0, currentInt - 50)
        let end = min(999, currentInt + 50)

        for i in start...end {
            if valueType == .decimal {
                options.append(String(i))
                if i < 999 {
                    options.append(WeightFormatter.format(Double(i) + 0.5, locale: locale))
                }
            } else {
                options.append(String(i))
            }
        }

        if !options.contains(displayText) {
            options.append(displayText)
        }

        options.sort { a, b in
            let aVal = WeightFormatter.parse(a) ?? 0
            let bVal = WeightFormatter.parse(b) ?? 0
            return aVal < bVal
        }

        return options
    }
}

// MARK: - Number Keypad (extracted component)

/// Pure digit input grid. Has no knowledge of scroll state.
private struct NumberKeypad: View {
    @Environment(\.appColorTheme) private var appColorTheme
    let valueType: NumberPadValueType
    let decimalSeparator: String
    let onDigit: (String) -> Void
    let onComma: () -> Void
    let onClear: () -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: AppStyle.Padding.titleTop) {
            digitRow("1", "2", "3")
            digitRow("4", "5", "6")
            digitRow("7", "8", "9")

            HStack(spacing: AppStyle.Padding.titleTop) {
                specialButton
                digitButton("0")
                deleteButtonView
            }

            actionRow
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .padding(.bottom, 120)
        .background(AppStyle.Color.sheetBackground)
    }

    private func digitRow(_ d1: String, _ d2: String, _ d3: String) -> some View {
        HStack(spacing: AppStyle.Padding.titleTop) {
            digitButton(d1)
            digitButton(d2)
            digitButton(d3)
        }
    }

    private func digitButton(_ digit: String) -> some View {
        Text(verbatim: digit)
            .font(AppStyle.Font.numberPadDisplay)
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, minHeight: AppStyle.Layout.numberPadKeySize)
            .onTapGesture { onDigit(digit) }
    }

    private var specialButton: some View {
        Text(verbatim: valueType == .decimal ? decimalSeparator : "C")
            .font(AppStyle.Font.navigationHeadline)
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, minHeight: AppStyle.Layout.numberPadKeySize)
            .onTapGesture {
                if valueType == .decimal {
                    onComma()
                } else {
                    onClear()
                }
            }
    }

    private var deleteButtonView: some View {
        Image(systemName: "delete.left")
            .font(AppStyle.Font.numberPadSymbol)
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, minHeight: AppStyle.Layout.numberPadKeySize)
            .onTapGesture { onDelete() }
    }

    private var actionRow: some View {
        HStack(spacing: AppStyle.Padding.card) {
            Button(AppText.actionCancel) { onCancel() }
                .font(AppStyle.Font.sectionTitle)
                .foregroundColor(AppStyle.Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)

            Button(AppText.actionApply) { onConfirm() }
                .font(AppStyle.Font.sectionHeadline)
                .foregroundColor(AppStyle.Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(appColorTheme.accent.primary)
                .cornerRadius(AppStyle.CornerRadius.defaultButton)
        }
        .padding(.horizontal, 24)
        .padding(.top, AppStyle.Padding.titleTop)
    }
}
