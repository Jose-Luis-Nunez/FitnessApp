import Foundation
import FitnessResources

public enum TransitPresentationFailure: Equatable, Sendable {
    case invalidURL
    case network
    case decoding
    case rateLimited
    case server(statusCode: Int)
    case unknown

    public var localizedResource: LocalizedStringResource {
        switch self {
        case .invalidURL: AppText.errorInvalidUrl
        case .network: AppText.errorNetworkUnreachable
        case .decoding: AppText.errorUnreadableResponse
        case .rateLimited: AppText.errorTooManyRequests
        case .server(let statusCode): AppText.errorTransitUnavailable(code: statusCode)
        case .unknown: AppText.errorFailedToLoad
        }
    }
}
