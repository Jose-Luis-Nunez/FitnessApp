import SwiftUI

enum NumberPadValueType {
    case integer, decimal
}

struct CustomNumberPadView: View {
    let currentValue: Double
    let isWeight: Bool
    let valueType: NumberPadValueType
    let onValueChange: (Double) -> Void
    let onDismiss: () -> Void
    
    @State private var currentDoubleValue: Double
    @State private var cursorOpacity: Double = 1.0
    @State private var shakeOffset: CGFloat = 0
    @State private var isScrolling = false
    @State private var centeredPickerValue: String = ""
    
    // Single source of truth: convert double to display string
    private var displayString: String {
        if valueType == .integer {
            return String(Int(currentDoubleValue))
        } else {
            if currentDoubleValue == floor(currentDoubleValue) {
                return String(Int(currentDoubleValue))
            } else {
                return String(currentDoubleValue).replacingOccurrences(of: ".", with: ",")
            }
        }
    }
    
    private var cursorXOffset: CGFloat {
        let charWidth: CGFloat = 16
        let textWidth = CGFloat(displayString.count) * charWidth
        return textWidth / 2 + 4
    }
    
    private var statusText: String {
        if currentDoubleValue >= 999.0 {
            return "Maximum erreicht"
        } else {
            return isWeight ? "kg" : "Wiederholungen"
        }
    }
    
    private var statusTextColor: Color {
        if currentDoubleValue >= 999.0 {
            return AppStyle.Color.greenGlow
        } else {
            return AppStyle.Color.gray
        }
    }
    
    init(currentValue: Double, isWeight: Bool, valueType: NumberPadValueType = .decimal, onValueChange: @escaping (Double) -> Void, onDismiss: @escaping () -> Void) {
        self.currentValue = currentValue
        self.isWeight = isWeight
        self.valueType = valueType
        self.onValueChange = onValueChange
        self.onDismiss = onDismiss
        
        _currentDoubleValue = State(initialValue: currentValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topDisplayArea
            numberPadSection
        }
        .background(AppStyle.Color.black)
        .cornerRadius(20)
        .shadow(radius: 20)
        .onAppear {
            cursorOpacity = 0.0
        }
        .offset(x: shakeOffset)
    }
    
    private var topDisplayArea: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { adjustValue(-1) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppStyle.Color.white)
                        .frame(width: 50, height: 50)
                }
                
                Spacer()
                
                scrollablePicker
                
                Spacer()
                
                Button(action: { adjustValue(1) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppStyle.Color.white)
                        .frame(width: 50, height: 50)
                }
            }
            .padding(.horizontal, 16)
            
            Text(statusText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(statusTextColor)
                .animation(.easeInOut(duration: 0.3), value: statusText)
        }
        .padding(.vertical, 16)
        .background(Color(hex: "#141518"))
    }
    
    private var scrollablePicker: some View {
        ZStack {
            ScrollViewReader { proxy in
                                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                        ForEach(generatePickerOptions(), id: \.self) { option in
                            Text(option)
                                .font(.system(size: 48, weight: (option == centeredPickerValue || option == displayString) ? .bold : .regular))
                                .foregroundColor(AppStyle.Color.white)
                                .opacity((option == centeredPickerValue || option == displayString) ? 1.0 : 0.3)
                                .onTapGesture {
                                    let newValue = Double(option.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                        currentDoubleValue = newValue
                                        proxy.scrollTo(option, anchor: UnitPoint.center)
                                    }
                                }
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear {
                                                updateCenteredValue(option: option, geometry: geo)
                                            }
                                            .onChange(of: geo.frame(in: .named("scroll")).midY) { _ in
                                                updateCenteredValue(option: option, geometry: geo)
                                            }
                                    }
                                )
                                .id(option)
                        }
                    }
                    .padding(.vertical, 50)
                }
                .coordinateSpace(name: "scroll")
                .frame(height: 100)
                .clipped()
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                            isScrolling = true
                        }
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isScrolling = false
                            }
                        }
                )
                .onAppear {
                    centeredPickerValue = displayString
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(displayString, anchor: UnitPoint.center)
                        }
                    }
                }
                .onChange(of: currentDoubleValue) { _ in
                    // Update centered value to match current display
                    centeredPickerValue = displayString
                    
                    // Only auto-scroll if user is not currently scrolling
                    if !isScrolling {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(displayString, anchor: UnitPoint.center)
                        }
                    }
                }
            }
            
            // Cursor
            if !isScrolling {
                Rectangle()
                    .fill(AppStyle.Color.white)
                    .frame(width: 2, height: 24)
                    .opacity(cursorOpacity)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: cursorOpacity)
                    .offset(x: cursorXOffset)
                    .allowsHitTesting(false)
            }
        }
    }
    
    private var numberPadSection: some View {
        VStack(spacing: 8) {
            // First row
            HStack(spacing: 8) {
                numberButton("1")
                numberButton("2")
                numberButton("3")
            }
            
            // Second row
            HStack(spacing: 8) {
                numberButton("4")
                numberButton("5")
                numberButton("6")
            }
            
            // Third row
            HStack(spacing: 8) {
                numberButton("7")
                numberButton("8")
                numberButton("9")
            }
            
            // Fourth row
            HStack(spacing: 8) {
                clearButton()
                numberButton("0")
                deleteButton()
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Abbrechen") {
                    onDismiss()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppStyle.Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .cornerRadius(12)
                
                Button("Übernehmen") {
                    onValueChange(currentDoubleValue)
                    onDismiss()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppStyle.Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppStyle.Color.green)
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 80)
        .background(Color(hex: "#222025"))
    }
    
    // MARK: - Actions
    
    private func adjustValue(_ delta: Int) {
        let newValue = max(0.0, min(999.0, currentDoubleValue + Double(delta)))
        
        if newValue == currentDoubleValue && delta > 0 {
            // At maximum, give feedback
            triggerMaximumFeedback()
        } else if newValue == currentDoubleValue && delta < 0 {
            // At minimum, give light feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } else {
            currentDoubleValue = newValue
        }
    }
    
    private func numberButton(_ digit: String) -> some View {
        Text(digit)
            .font(.system(size: 32, weight: .regular))
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, minHeight: 70)
            .onTapGesture {
                appendDigit(digit)
            }
    }
    
    private func clearButton() -> some View {
        Text(valueType == .decimal ? "," : "C")
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, minHeight: 70)
            .onTapGesture {
                if valueType == .decimal {
                    appendComma()
                } else {
                    currentDoubleValue = 0.0
                }
            }
    }
    
    private func deleteButton() -> some View {
        Image(systemName: "delete.left")
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, minHeight: 70)
            .onTapGesture {
                deleteLastDigit()
            }
    }
    
    // MARK: - Helper Functions
    
    private func updateCenteredValue(option: String, geometry: GeometryProxy) {
        let frame = geometry.frame(in: .named("scroll"))
        let centerY: CGFloat = 50  // Half of scroll view height (100/2)
        
        // Update visual highlighting for any option near center
        if abs(frame.midY - centerY) < 6 {
            centeredPickerValue = option
            
            // Only update actual value when user is actively scrolling
            if isScrolling {
                let newValue = Double(option.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                if currentDoubleValue != newValue {
                    currentDoubleValue = newValue
                    
                    // Light haptic feedback for value change
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
        }
    }
    
    private func appendDigit(_ digit: String) {
        let currentString = displayString
        
        if valueType == .integer {
            // Integer mode: max 3 digits
            if currentString.count < 3 {
                let newString = currentString == "0" ? digit : currentString + digit
                currentDoubleValue = Double(newString) ?? 0.0
            } else {
                // Jump to maximum
                currentDoubleValue = 999.0
                triggerMaximumFeedback()
            }
        } else {
            // Decimal mode
            let parts = currentString.components(separatedBy: ",")
            if parts.count == 1 {
                // No comma yet
                if parts[0].count < 3 {
                    let newString = currentString == "0" ? digit : currentString + digit
                    currentDoubleValue = Double(newString) ?? 0.0
                } else {
                    // Jump to maximum when 4th digit
                    currentDoubleValue = 999.0
                    triggerMaximumFeedback()
                }
            } else {
                // Has comma
                if parts[1].count < 2 {
                    let newString = currentString + digit
                    currentDoubleValue = Double(newString.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                } else {
                    // Max decimal places reached - give full feedback
                    triggerMaximumFeedback()
                }
            }
        }
    }
    
    private func appendComma() {
        let currentString = displayString
        if !currentString.contains(",") && currentString != "0" {
            currentDoubleValue = Double(currentString + ".0") ?? currentDoubleValue
        }
    }
    
    private func deleteLastDigit() {
        let currentString = displayString
        if currentString.count > 1 {
            var newString = String(currentString.dropLast())
            if newString.hasSuffix(",") {
                newString = String(newString.dropLast())
            }
            currentDoubleValue = Double(newString.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        } else {
            currentDoubleValue = 0.0
        }
    }
    
    private func triggerMaximumFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.interpolatingSpring(stiffness: 500, damping: 5)) {
            shakeOffset = -10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.interpolatingSpring(stiffness: 500, damping: 5)) {
                shakeOffset = 10
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.interpolatingSpring(stiffness: 500, damping: 5)) {
                    shakeOffset = 0
                }
            }
        }
    }
    
    private func generatePickerOptions() -> [String] {
        var options: [String] = []
        
        if valueType == .integer {
            for i in 0...999 {
                options.append(String(i))
            }
        } else {
            for i in 0...999 {
                options.append(String(i))
                if i < 999 {
                    let halfValue = Double(i) + 0.5
                    options.append(String(halfValue).replacingOccurrences(of: ".", with: ","))
                }
            }
        }
        
        // Always include the current displayString if it's not already in the list
        if !options.contains(displayString) {
            options.append(displayString)
        }
        
        return options.sorted { a, b in
            let aValue = Double(a.replacingOccurrences(of: ",", with: ".")) ?? 0
            let bValue = Double(b.replacingOccurrences(of: ",", with: ".")) ?? 0
            return aValue < bValue
        }
    }
}
