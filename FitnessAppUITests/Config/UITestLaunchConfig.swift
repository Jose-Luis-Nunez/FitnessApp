#if UITESTING
import Foundation

struct UITestLaunchConfig: Codable {
    let screen: UITestScreen
    let category: String
    var exerciseName: String?
    var weight: Double?
    var reps: Int?
    var sets: Int?
    var noSeats: Bool?
    var icon: String?

    // MARK: - Factory Methods

    static func category(_ name: String) -> UITestLaunchConfig {
        UITestLaunchConfig(screen: .category, category: name)
    }

    static func schedule() -> UITestLaunchConfig {
        UITestLaunchConfig(screen: .schedule, category: "")
    }

    // MARK: - Encoding

    func jsonString() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8)!
    }

    // MARK: - Decoding (app-side)

    static func from(environment: [String: String]) -> UITestLaunchConfig? {
        guard let json = environment["UITEST_CONFIG"],
              let data = json.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(UITestLaunchConfig.self, from: data)
    }
}
#endif // UITESTING
