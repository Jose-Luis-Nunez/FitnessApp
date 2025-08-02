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
    
    @State private var displayValue: String = ""
    @State private var cursorOpacity: Double = 1.0
    @State private var shakeOffset: CGFloat = 0
    @State private var focusedValue: String = ""
    
    private var cursorXOffset: CGFloat {
        // Calculate cursor position based on text length
        let charWidth: CGFloat = 16 // Approximate width of one digit in 32pt font
        let textWidth = CGFloat(displayValue.count) * charWidth
        return textWidth / 2 + 4 // Position at the end of the text + small gap
    }
    
    private var statusText: String {
        let value = Double(displayValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        if value >= 999.0 {
            return "Maximum erreicht"
        } else {
            return isWeight ? "kg" : "Wiederholungen"
        }
    }
    
    private var statusTextColor: Color {
        let value = Double(displayValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        if value >= 999.0 {
            return AppStyle.Color.greenGlow // Orange/yellow for warning
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
        
        // Format the initial value based on type
        if valueType == .integer {
            let initialVal = String(Int(currentValue))
            _displayValue = State(initialValue: initialVal)
            _focusedValue = State(initialValue: initialVal)
        } else {
            let formattedValue = currentValue == floor(currentValue) ? 
                String(Int(currentValue)) : 
                String(currentValue).replacingOccurrences(of: ".", with: ",")
            _displayValue = State(initialValue: formattedValue)
            _focusedValue = State(initialValue: formattedValue)
        }
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
                    let value = Double(displayValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                    onValueChange(value)
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
    
    // MARK: - Helper Views
    
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
        VStack {
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 24) {
                            ForEach(generatePickerOptions(), id: \.self) { option in
                                pickerOption(option: option, proxy: proxy)
                            }
                        }
                        .padding(.vertical, 50)
                    }
                    .coordinateSpace(name: "scroll")
                    .frame(height: 100)
                    .clipped()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(focusedValue, anchor: UnitPoint.center)
                            }
                        }
                    }
                }
                
                if displayValue == focusedValue {
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
    }
    
    private func pickerOption(option: String, proxy: ScrollViewProxy) -> some View {
        Text(option)
            .font(.system(size: 32, weight: option == focusedValue ? .bold : .regular))
            .foregroundColor(AppStyle.Color.white)
            .opacity(option == focusedValue ? 1.0 : 0.3)
            .animation(.easeInOut(duration: 0.2), value: focusedValue)
            .onTapGesture { 
                selectValue(option, proxy: proxy)
            }
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            let frame = geo.frame(in: .named("scroll"))
                            if abs(frame.midY - 50) < 24 {
                                focusedValue = option
                                displayValue = option
                            }
                        }
                        .onChange(of: geo.frame(in: .named("scroll")).midY) { midY in
                            if abs(midY - 50) < 24 {
                                focusedValue = option
                                displayValue = option
                            }
                        }
                }
            )
            .id(option)
    }
    
    private func selectValue(_ value: String, proxy: ScrollViewProxy) {
        focusedValue = value
        displayValue = value
        
        // Snap to the selected value
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(value, anchor: UnitPoint.center)
        }
    }
    
    private func generatePickerOptions() -> [String] {
        var options: [String] = []
        
        if valueType == .integer {
            // For integers: 0, 1, 2, ..., 999
            for i in 0...999 {
                options.append(String(i))
            }
        } else {
            // For decimals: 0, 0,5, 1, 1,5, ..., 999
            for i in 0...999 {
                // Add whole numbers
                options.append(String(i))
                // Add half numbers (except for the last one to avoid 999,5)
                if i < 999 {
                    let halfValue = Double(i) + 0.5
                    options.append(String(halfValue).replacingOccurrences(of: ".", with: ","))
                }
            }
        }
        
        return options
    }
    
    private func numberButton(_ number: String) -> some View {
        Text(number)
            .font(.system(size: 32, weight: .regular))
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, minHeight: 70)
            .onTapGesture {
                withAnimation(.none) {
                    if displayValue == "0" || displayValue.isEmpty {
                        displayValue = number
                                        } else {
                        if valueType == .integer {
                            // Integer mode: max 3 digits, no decimals
                            if displayValue.count < 3 {
                                displayValue += number
                            } else {
                                // Jump to 999 for integers
                                displayValue = "999"
                                
                                // Give haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                // Shake animation
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
                        } else {
                            // Decimal mode: handle comma input
                            let parts = displayValue.components(separatedBy: ",")
                            if parts.count == 1 {
                                // No comma yet, check if we can add more digits (max 3 digits before comma)
                                if parts[0].count < 3 {
                                    displayValue += number
                                } else {
                                    // Jump to maximum when trying to add a 4th digit before comma
                                    displayValue = "999"
                                    
                                    // Give haptic feedback to signal the jump to max
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    
                                    // Shake animation for visual feedback
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
                            } else {
                                // Already has comma, add digit after comma (max 2 decimal places)
                                if parts[1].count < 2 {
                                    displayValue += number
                                } else {
                                    // Give feedback when trying to add more than 2 decimal places
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                            }
                        }
                    }
                }
            }
    }
    
    private func clearButton() -> some View {
        Text(valueType == .decimal ? "," : "C")
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, minHeight: 70)
            .onTapGesture {
                withAnimation(.none) {
                    if valueType == .decimal {
                        // Add comma if not already present and not empty
                        if !displayValue.contains(",") && displayValue != "0" && !displayValue.isEmpty {
                            displayValue += ","
                        }
                    } else {
                        // Clear for integer mode
                        displayValue = "0"
                    }
                }
            }
    }
    
    private func deleteButton() -> some View {
        Image(systemName: "delete.left")
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, minHeight: 70)
            .onTapGesture {
                withAnimation(.none) {
                    if displayValue.count > 1 {
                        displayValue.removeLast()
                        // If we deleted everything after comma, also remove the comma
                        if displayValue.hasSuffix(",") {
                            displayValue.removeLast()
                        }
                    } else {
                        displayValue = "0"
                    }
                }
            }
    }
    
    private func adjustValue(_ delta: Int) {
        withAnimation(.none) {
            // Convert displayValue to Double for calculation
            let currentDouble = Double(displayValue.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            let newValue = max(0.0, min(999.0, currentDouble + Double(delta)))
            
            if newValue != currentDouble + Double(delta) && delta > 0 {
                // Give feedback when trying to go above 999
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Shake animation
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
            
            // Format back to display format
            if newValue == floor(newValue) {
                displayValue = String(Int(newValue))
            } else {
                displayValue = String(newValue).replacingOccurrences(of: ".", with: ",")
            }
        }
    }
} 
