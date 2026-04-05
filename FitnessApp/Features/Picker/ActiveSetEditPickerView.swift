import SwiftUI
import UIKit

struct ActiveSetEditPickerView: View {
    let title: String
    @Binding var selectedReps: String
    @Binding var selectedWeight: String
    let repsRange: ClosedRange<Int>
    let weightOptions: [String]
    let onSave: (Int, Double) -> Void
    let onCancel: () -> Void
    let saveDisabled: Bool
    
    let textColor: Color = AppStyle.Color.white
    let backgroundColor = AppStyle.Color.black
    let pickerColor: Color = AppStyle.Color.greenLight
    
    let cancelButtonTextColor: Color = AppStyle.Color.white
    
    let saveButtonTextDisabledColor: Color = AppStyle.Color.white
    let saveButtonBackgroundDisabledColor: Color = AppStyle.Color.green.opacity(0.15)
    
    let saveButtonTextEnabledColor: Color = AppStyle.Color.white
    let saveButtonBackgroundEnabledColor: Color = AppStyle.Color.green

    // Default: deaktiviert; wird im onAppear anhand der aktuellen Auswahl ggf. aktiviert
    @State private var showDecimal: Bool = false
    private var filteredWeightOptions: [String] {
        showDecimal ? weightOptions : weightOptions.filter { !$0.contains(",") && !$0.contains(".") }
    }
    
    var body: some View {
        ZStack {
            // Dimmed backdrop to capture outside taps and keep picker on top
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            // Panel (bottom sheet)
            VStack(alignment: .center, spacing: 8) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                VStack(spacing: 8) {
                    // Titel eine Ebene höher, zentriert
                    Text(title)
                        .font(.title2)
                        .foregroundColor(textColor)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)

                    // Darunter: Switch rechts ausgerichtet
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Text("Decimal")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(textColor.opacity(0.85))
                            Toggle("", isOn: $showDecimal)
                                .labelsHidden()
                                .toggleStyle(CapsuleToggleStyle(onColor: AppStyle.Color.greenGlow, offColor: Color.gray.opacity(0.4)))
                        }
                    }
                }
                .padding(.bottom, 18)
                
                VStack(spacing: 0) {
                    HStack {
                        Text("Wiederholung")
                            .font(.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                        Text("Gewicht")
                            .font(.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                    }
                    
                    HStack {
                        Picker("Reps", selection: $selectedReps) {
                            ForEach(repsRange.map(String.init), id: \.self) { value in
                                Text(value).tag(value).foregroundColor(pickerColor)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        
                        Picker("Weight", selection: $selectedWeight) {
                            ForEach(filteredWeightOptions, id: \.self) { value in
                                Text("\(value) kg").tag(value).foregroundColor(pickerColor)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    .frame(height: 120)
                }
                
                HStack() {
                    Spacer()
                    
                    Text("Cancel")
                        .foregroundColor(cancelButtonTextColor)
                        .font(.system(size: 14))
                        .padding(.vertical, 8)
                        .frame(width: 120)
                        .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                        .onTapGesture {
                            onCancel()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer()
                    
                    Button("Save") {
                        if let reps = Int(selectedReps) {
                            let weightString = selectedWeight.replacingOccurrences(of: ",", with: ".")
                            if let weight = Double(weightString) {
                                onSave(reps, weight)
                            }
                        }
                    }
                    .foregroundColor(saveDisabled ? saveButtonTextDisabledColor : saveButtonTextEnabledColor)
                    .font(.system(size: 14))
                    .padding(.vertical, 8)
                    .frame(width: 140,height: 40)
                    .background(saveDisabled ? saveButtonBackgroundDisabledColor : saveButtonBackgroundEnabledColor)
                    .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                    .disabled(saveDisabled)
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)   // etwas höher, damit mehr vertikaler Raum entsteht
            .padding(.bottom, 28)
            .background(
                RoundedCorner(radius: 22, corners: [.topLeft, .topRight])
                    .fill(Color(hex: "#222025"))
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 420, alignment: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 0)
            .padding(.bottom, 0)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height > 80 {
                        onCancel()
                    }
                }
            )
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            // Aktivieren, wenn bereits eine Dezimalzahl vorliegt
            if selectedWeight.contains(",") || selectedWeight.contains(".") {
                showDecimal = true
            }
        }
    }
}

// Utility shape for top-only rounded corners (bottom sheet)
private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// Uses shared CapsuleToggleStyle (defined in Shared/View)
