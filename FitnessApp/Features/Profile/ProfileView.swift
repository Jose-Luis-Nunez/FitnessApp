import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                if viewModel.isNicknameSet {
                    greetingView
                } else {
                    nicknameInputView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle(viewModel.greetingTitle)
            .alert(isPresented: $viewModel.showAlert) {
                Alert(title: Text("Error"), message: Text("Nickname cannot be empty"), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private var greetingView: some View {
        Text(viewModel.greetingMessage)
            .font(.title2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 20)
            .padding(.horizontal)
    }
    
    private var nicknameInputView: some View {
        VStack(spacing: 20) {
            TextField("Enter your nickname", text: $viewModel.nickname)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Save") {
                if viewModel.saveNickname() {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppStyle.Color.green)
            .disabled(viewModel.nickname.isEmpty)
        }
    }
}
