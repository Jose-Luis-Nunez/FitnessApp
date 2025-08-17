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
    
    @State private var inputValue: Double
    @State private var showComma: Bool = false
    @State private var shakeOffset: CGFloat = 0
    
    @State private var displayText: String = "0"
    @State private var isUserScrolling: Bool = false
    @State private var isInitialized: Bool = false
    
    
    init(currentValue: Double, isWeight: Bool, valueType: NumberPadValueType = .decimal, onValueChange: @escaping (Double) -> Void, onDismiss: @escaping () -> Void) {
        self.currentValue = currentValue
        self.isWeight = isWeight
        self.valueType = valueType
        self.onValueChange = onValueChange
        self.onDismiss = onDismiss
        
        _inputValue = State(wrappedValue: currentValue)
        _showComma = State(wrappedValue: currentValue != floor(currentValue))
        
        _displayText = State(wrappedValue: WeightFormatter.format(currentValue))
    }
    
    private var displayString: String {
        if valueType == .integer {
            return String(Int(inputValue))
        } else {
            if inputValue == floor(inputValue) && !showComma {
                return String(Int(inputValue))
            } else if inputValue == floor(inputValue) && showComma {
                return String(Int(inputValue)) + ","
            } else {
                return WeightFormatter.format(inputValue)
            }
        }
    }
    
    private var statusText: String {
        if inputValue >= 999.0 {
            return "Maximum reached"
        } else {
            return isWeight ? "kg" : "Wiederholungen"
        }
    }
    
    private var statusTextColor: Color {
        inputValue >= 999.0 ? AppStyle.Color.green : AppStyle.Color.white
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topDisplayArea
                numberPadSection
            }
            .background(AppStyle.Color.black)
            .cornerRadius(20)
            .shadow(radius: 20)
            .offset(x: shakeOffset)
        }
        .onAppear {
            DispatchQueue.main.async {
                inputValue = currentValue
                showComma = currentValue != floor(currentValue)
                updateDisplayText()
                isInitialized = false
            }
        }
    }
    
    private var topDisplayArea: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { adjustValue(-1) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(Color(hex: "#555555"))
                        .frame(width: 50, height: 50)
                }
                
                Spacer()
                
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(getExtendedPickerRange(), id: \.self) { option in
                                Text(option)
                                    .font(.system(size: option == displayText ? 48 : 24, weight: option == displayText ? .bold : .regular))
                                    .foregroundColor(AppStyle.Color.white)
                                    .opacity(option == displayText ? 1.0 : 0.3)
                                    .onTapGesture {
                                        if let value = Double(option.replacingOccurrences(of: ",", with: ".")) {
                                            inputValue = value
                                            showComma = option.contains(",") && option.hasSuffix(",")
                                            updateDisplayText()
                                            
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                proxy.scrollTo(option, anchor: .center)
                                            }
                                        }
                                    }
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear
                                                .onAppear {
                                                    if isInitialized {
                                                        checkIfCentered(option: option, geometry: geo)
                                                    }
                                                }
                                                .onChange(of: geo.frame(in: .named("picker")).midY) { _, _ in
                                                    if isUserScrolling && isInitialized {
                                                        checkIfCentered(option: option, geometry: geo)
                                                    }
                                                }
                                        }
                                    )
                                    .id(option)
                            }
                        }
                        .padding(.vertical, 60)
                    }
                    .coordinateSpace(name: "picker")
                    .frame(height: 120)
                    .clipped()
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { _ in
                                isUserScrolling = true
                            }
                            .onEnded { _ in
                                isUserScrolling = false
                            }
                    )
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(displayText, anchor: .center)
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isInitialized = true
                            }
                        }
                    }
                    .onChange(of: displayText) { _, newValue in
                        if !isUserScrolling {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(newValue, anchor: .center)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { adjustValue(1) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(Color(hex: "#555555"))
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
        .background(Color(hex: "#141518").opacity(0.85))
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
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    onDismiss()
                }
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppStyle.Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                
                Button("Übernehmen") {
                    onValueChange(inputValue)
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
                    clearValue()
                }
            }
    }
    
    private func deleteButton() -> some View {
        Image(systemName: "delete.left")
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, minHeight: 70)
            .onTapGesture {
                deleteLastDigit()
            }
    }
        
    private func getExtendedPickerRange() -> [String] {
        let currentInt = Int(inputValue)
        var options: [String] = []
        
        let start = max(0, currentInt - 50)
        let end = min(999, currentInt + 50)
        
        for i in start...end {
            if valueType == .decimal {
                options.append(String(i))
                if i < 999 {
                    options.append("\(i),5")
                }
            } else {
                options.append(String(i))
            }
        }
        
        if !options.contains(displayText) {
            options.append(displayText)
        }
        
        options.sort { (a, b) in
            let aVal = Double(a.replacingOccurrences(of: ",", with: ".")) ?? 0
            let bVal = Double(b.replacingOccurrences(of: ",", with: ".")) ?? 0
            return aVal < bVal
        }
        
        return options
    }
    
    private func checkIfCentered(option: String, geometry: GeometryProxy) {
        guard isInitialized && isUserScrolling else { return }
        
        let frame = geometry.frame(in: .named("picker"))
        let pickerHeight: CGFloat = 120
        let center = pickerHeight / 2 + 15
        
        if abs(frame.midY - center) < 12 {
            if option != displayText {
                if let value = Double(option.replacingOccurrences(of: ",", with: ".")) {
                    inputValue = value
                    showComma = option.contains(",") && option.hasSuffix(",")
                    updateDisplayText()
                    
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            }
        }
    }
    
    private func appendDigit(_ digit: String) {
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
            let parts = currentString.components(separatedBy: ",")
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
        updateDisplayText()
    }
    
    private func appendComma() {
        if valueType == .decimal {
            let currentString = displayText
            if !currentString.contains(",") && currentString != "0" {
                showComma = true
                updateDisplayText()
            }
        }
    }
    
    private func deleteLastDigit() {
        let currentString = displayText
        if currentString.count > 1 {
            var newString = String(currentString.dropLast())
            if newString.hasSuffix(",") {
                newString = String(newString.dropLast())
                showComma = false
            }
            inputValue = Double(newString.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            showComma = newString.contains(",") || showComma
        } else {
            inputValue = 0.0
            showComma = false
        }
        updateDisplayText()
    }
    
    private func clearValue() {
        inputValue = 0.0
        showComma = false
        updateDisplayText()
    }
    
    private func adjustValue(_ delta: Int) {
        let newValue = max(0.0, min(999.0, inputValue + Double(delta)))
        
        if newValue == inputValue && delta > 0 {
            triggerMaximumFeedback()
        } else if newValue == inputValue && delta < 0 {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } else {
            inputValue = newValue
            showComma = false
            updateDisplayText()
        }
    }
    
    private func setPickerValue(_ option: String) {
        let newValue = Double(option.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        inputValue = newValue
        showComma = option.contains(",") && option.hasSuffix(",")
        updateDisplayText()
    }
    
    private func updateDisplayText() {
        displayText = displayString
    }
    
    private func shouldAutoScroll() -> Bool {
        if valueType == .decimal && displayText.hasSuffix(",") {
            return false
        }
        return true
    }
    
    
    private func triggerMaximumFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
            shakeOffset = 10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                shakeOffset = 0
            }
        }
    }
}
