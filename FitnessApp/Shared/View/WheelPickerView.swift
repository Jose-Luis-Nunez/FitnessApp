import SwiftUI

struct WheelPickerView: View {
    let title: String
    @Binding var selectedValue: Int
    let range: ClosedRange<Int>
    let unit: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppStyle.Color.gray)
            
            Picker(title, selection: $selectedValue) {
                ForEach(range, id: \.self) { value in
                    Text("\(value) \(unit)")
                        .font(.title3)
                        .foregroundColor(AppStyle.Color.white)
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .background(AppStyle.Color.grayDark.opacity(0.2))
            .onAppear {
                if !range.contains(selectedValue) {
                    selectedValue = range.lowerBound
                }
            }
        }
    }
}
