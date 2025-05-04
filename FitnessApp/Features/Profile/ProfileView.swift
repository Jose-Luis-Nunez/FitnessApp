import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text(viewModel.greetingTitle)
                .font(.largeTitle)
                .foregroundColor(.white)
            
            Text(viewModel.greetingMessage)
                .font(.title2)
                .foregroundColor(.white)
            
            TextField("Nickname", text: $viewModel.nickname)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .foregroundColor(.black)
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(8)
                .disabled(viewModel.isNicknameSet)
            
            Button(action: {
                if viewModel.saveNickname() {
                    print("Nickname saved successfully")
                }
            }) {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(viewModel.isNicknameSet ? Color.gray : Color.blue)
                    .cornerRadius(8)
            }
            .disabled(viewModel.isNicknameSet)
            
            if viewModel.showAlert {
                Text("Nickname cannot be empty!")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppStyle.Color.backgroundColor)
        .padding()
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("Error"), message: Text("Nickname cannot be empty!"), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            print("Minimal ProfileView appeared")
        }
    }
}
