import Foundation

class ProfileViewModel: ObservableObject {
    @Published var nickname: String
    @Published var showAlert = false
    
    private let userDefaults = UserDefaults.standard
    private let nicknameKey = "userNickname"
    
    init() {
        self.nickname = userDefaults.string(forKey: nicknameKey) ?? ""
    }
    
    var isNicknameSet: Bool {
        !nickname.isEmpty
    }
    
    var greetingTitle: String {
        isNicknameSet ? "Hallo \(nickname)!" : "Profile"
    }
    
    var greetingMessage: String {
        isNicknameSet ? "Willkommen zurück, \(nickname)!" : ""
    }
    
    func saveNickname() -> Bool {
        guard !isNicknameSet else {
            return false
        }
        
        guard isNicknameValid() else {
            showAlert = true
            return false
        }
        
        persistNickname()
        return true
    }
    
    private func isNicknameValid() -> Bool {
        !nickname.isEmpty
    }
    
    private func persistNickname() {
        userDefaults.set(nickname, forKey: nicknameKey)
    }
}
