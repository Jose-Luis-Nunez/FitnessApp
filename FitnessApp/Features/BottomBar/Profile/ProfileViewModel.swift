import Foundation

class ProfileViewModel: ObservableObject {
    
    @Published var nickname: String {
        didSet {
            if nickname.isEmpty {
                showAlert = true
            }
        }
    }
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
        isNicknameSet ? "Hey \(nickname)" : "Profile"
    }
    
    var greetingMessage: String {
        isNicknameSet ? "Willkommen zurück!" : ""
    }
    
    func saveNickname() -> Bool {
        guard !nickname.isEmpty else {
            showAlert = true
            return false
        }
        
        persistNickname()
        return true
    }
    
    private func persistNickname() {
        userDefaults.set(nickname, forKey: nicknameKey)
    }
}
