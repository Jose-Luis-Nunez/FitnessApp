import SwiftUI

struct EditPickerView: View {
    let title: String
    @Binding var selectedReps: String
    @Binding var selectedWeight: String
    let repsRange: ClosedRange<Int>
    let weightRange: ClosedRange<Int>
    let onSave: (Int, Int) -> Void
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
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea(edges: .bottom)
            
            VStack(alignment: .center, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .foregroundColor(textColor)
                    .fontWeight(.bold)
                    .padding(.bottom, 16)
                
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
                            ForEach(weightRange.map(String.init), id: \.self) { value in
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
                    
                    Text("Abbrechen")
                        .foregroundColor(cancelButtonTextColor)
                        .font(.system(size: 14))
                        .padding(5)
                        .frame(width: 120)
                        .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                        .onTapGesture {
                            onCancel()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer()
                    
                    Button("Speichern") {
                        if let reps = Int(selectedReps), let weight = Int(selectedWeight) {
                            onSave(reps, weight)
                        }
                    }
                    .foregroundColor(saveDisabled ? saveButtonTextDisabledColor : saveButtonTextEnabledColor)
                    .font(.system(size: 14))
                    .padding(5)
                    .frame(width: 140,height: 40)
                    .background(saveDisabled ? saveButtonBackgroundDisabledColor : saveButtonBackgroundEnabledColor)
                    .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                    .disabled(saveDisabled)
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer()
                }
                .padding(.horizontal, 5)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }
}
