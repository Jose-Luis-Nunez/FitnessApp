import SwiftUI

struct CalendarDialogView: View {
    @Binding var isPresented: Bool
    @Binding var selectedDate: Date
    @State private var tempDate: Date
    let highlightedDates: [Date]
    let title: String
    
    init(
        isPresented: Binding<Bool>,
        selectedDate: Binding<Date>,
        highlightedDates: [Date] = [],
        title: String = "Training Calendar"
    ) {
        self._isPresented = isPresented
        self._selectedDate = selectedDate
        self._tempDate = State(wrappedValue: selectedDate.wrappedValue)
        self.highlightedDates = highlightedDates
        self.title = title
    }
    
    var body: some View {
        Group {
            if isPresented {
                ZStack {
                    // Tappable background area
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
                                    highlightedDates: highlightedDates
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal)
                                
                                actionButtons
                            }
                            .background(AppStyle.Color.greenBlack)
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
            .background(AppStyle.Color.green)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
}
