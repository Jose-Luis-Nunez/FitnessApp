import SwiftUI

struct ExercisePickerView: View {
    let title: String
    @Binding var name: String
    @Binding var reps: Int
    @Binding var weight: Int
    @Binding var sets: Int
    @Binding var isPresented: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let saveDisabled: Bool
    let repsRange: ClosedRange<Int>
    let weightRange: ClosedRange<Int>
    let setsRange: ClosedRange<Int>
    let viewModel: MuscleCategoryViewModel
    let editingExercise: Exercise?
    
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
                HStack {
                    Text(title)
                        .font(.title2)
                        .foregroundColor(textColor)
                        .fontWeight(.bold)
                        .padding(.bottom, 16)
                    
                    Spacer()
                    
                    if let exercise = editingExercise {
                        Button(action: {
                            
                            if let index = viewModel.exercises.firstIndex(where: { $0.id == exercise.id }) {
                                viewModel.exercises.remove(at: index)
                            }
                            onCancel()
                            isPresented = false
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(AppStyle.Color.white)
                                .imageScale(.large)
                        }
                        .padding(.trailing, 8)
                    }
                    
                }
                .padding(.bottom, 16)
                
                TextField("Name der Übung", text: $name)
                    .padding(12)
                    .background(AppStyle.Color.backgroundColor)
                    .cornerRadius(10)
                    .foregroundColor(textColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppStyle.Color.gray, lineWidth: 1)
                    )
                    .padding(.bottom, 16)
                
                HStack(alignment: .top, spacing: 0) {
                    VStack {
                        Text("Sätze")
                            .font(.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                        Picker("Sets", selection: $sets) {
                            ForEach(setsRange, id: \.self) { value in
                                Text("\(value)").tag(value).foregroundColor(pickerColor)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    
                    VStack {
                        Text("Wiederholung")
                            .font(.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                        Picker("Reps", selection: $reps) {
                            ForEach(repsRange, id: \.self) { value in
                                Text("\(value)").tag(value).foregroundColor(pickerColor)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                    
                    VStack {
                        Text("Gewicht")
                            .font(.headline)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                        Picker("Weight", selection: $weight) {
                            ForEach(weightRange, id: \.self) { value in
                                Text("\(value) kg").tag(value).foregroundColor(pickerColor)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                }
                .frame(height: 120)
                
                HStack {
                    Spacer()
                    
                    Text("Abbrechen")
                        .foregroundColor(cancelButtonTextColor)
                        .font(.system(size: 14))
                        .padding(5)
                        .frame(width: 120)
                        .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                        .onTapGesture {
                            onCancel()
                            isPresented = false
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer()
                    
                    Button("Speichern") {
                        onSave()
                        isPresented = false
                    }
                    .foregroundColor(saveDisabled ? saveButtonTextDisabledColor : saveButtonTextEnabledColor)
                    .font(.system(size: 14))
                    .padding(5)
                    .frame(width: 140, height: 40)
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
