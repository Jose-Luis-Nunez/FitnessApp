import SwiftUI

struct WheelPickerView: View {
    let title: String
    @Binding var selectedValue: String
    let range: ClosedRange<Int>
    let unit: String
    
    private var validSelectedValue: String {
        if selectedValue.isEmpty || Int(selectedValue) == nil || !range.contains(Int(selectedValue) ?? 0) {
            return String(range.lowerBound)
        }
        return selectedValue
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
            Picker(title, selection: $selectedValue) {
                ForEach(range, id: \.self) { value in
                    Text("\(value) \(unit)").tag(String(value))
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 100)
            .onAppear {
                if selectedValue.isEmpty {
                    selectedValue = String(range.lowerBound)
                }
            }
        }
    }
}
