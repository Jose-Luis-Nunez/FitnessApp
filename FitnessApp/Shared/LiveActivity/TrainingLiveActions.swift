import Foundation

enum TrainingLiveAction: String {
    case done
    case less
    case more
}

extension Notification.Name {
    static let trainingLiveAction = Notification.Name("training.live.action")
}

struct TrainingLiveActionRouter {
    static func post(_ action: TrainingLiveAction) {
        NotificationCenter.default.post(name: .trainingLiveAction, object: nil, userInfo: ["action": action.rawValue])
    }
}


