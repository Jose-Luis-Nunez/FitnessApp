import SwiftUI
import FitnessUI

struct ProfileView: View {
    @AppStorage("userNickname") private var nickname: String = ""
    @State private var inputNickname: String = ""
    @State private var showAlert = false
    @State private var isEditing = false
    
    let textColor: Color = AppStyle.Color.white
    let backgroundColor = AppStyle.Color.black
    let saveButtonBackgroundEnabledColor: Color = AppStyle.Color.green
    let saveButtonBackgroundDisabledColor: Color = AppStyle.Color.green.opacity(0.15)
    let saveButtonTextEnabledColor: Color = AppStyle.Color.white
    let saveButtonTextDisabledColor: Color = AppStyle.Color.white
    let cancelButtonTextColor: Color = AppStyle.Color.white
    
    var body: some View {
        VStack(spacing: 16) {
            if !nickname.isEmpty && !isEditing {
                Button(action: {
                    isEditing = true
                    inputNickname = nickname
                }) {
                    Text("Hey \(nickname)")
                        .font(.largeTitle)
                        .foregroundColor(textColor)
                }
                Text("Willkommen zurück!")
                    .font(.title2)
                    .foregroundColor(textColor)
            } else {
                Text(nickname.isEmpty ? "Profile" : "Hey \(nickname)")
                    .font(.largeTitle)
                    .foregroundColor(textColor)
                
                if isEditing || nickname.isEmpty {
                    TextField("Nickname", text: $inputNickname)
                        .foregroundColor(textColor)
                        .padding()
                        .background(backgroundColor)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .frame(width: 250)
                    
                    HStack {
                        Spacer()
                        
                        Text("Cancel")
                            .foregroundColor(cancelButtonTextColor)
                            .font(AppStyle.Font.pickerAction)
                            .padding(5)
                            .frame(width: 120)
                            .cornerRadius(8)
                            .onTapGesture {
                                inputNickname = ""
                                isEditing = false
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Spacer()
                        
                        Button(action: {
                            if inputNickname.isEmpty {
                                showAlert = true
                            } else {
                                nickname = inputNickname
                                inputNickname = ""
                                isEditing = false
                                print("Nickname saved successfully")
                            }
                        }) {
                            Text("Save")
                                .foregroundColor(inputNickname.isEmpty ? saveButtonTextDisabledColor : saveButtonTextEnabledColor)
                                .font(AppStyle.Font.pickerAction)
                                .padding(5)
                                .frame(width: 140, height: 40)
                                .background(inputNickname.isEmpty ? saveButtonBackgroundDisabledColor : saveButtonBackgroundEnabledColor)
                                .cornerRadius(8)
                        }
                        .disabled(inputNickname.isEmpty)
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 5)
                }
                
                if nickname.isEmpty {
                    Text("Willkommen zurück!")
                        .font(.title2)
                        .foregroundColor(textColor)
                }
            }
            
            if showAlert {
                Text("Nickname cannot be empty!")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(backgroundColor)
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text("Nickname cannot be empty!"), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            print("Minimal ProfileView appeared")
        }
    }
}

