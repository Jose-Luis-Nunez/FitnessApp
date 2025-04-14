import Foundation

// MARK: - App Error
enum AppError: LocalizedError {
    case storage(StorageError)
    case validation(Exercise.ValidationError)
    case network(Error)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .storage(let error):
            return error.localizedDescription
        case .validation(let error):
            return error.localizedDescription
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .storage:
            return "Try restarting the app"
        case .validation:
            return "Please check your input values"
        case .network:
            return "Check your internet connection and try again"
        case .unknown:
            return "Please try again later"
        }
    }
}

// MARK: - Error Handler
final class ErrorHandler {
    // MARK: - Properties
    static let shared = ErrorHandler()
    private var errorObservers: [(AppError) -> Void] = []
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    func handle(_ error: AppError) {
        errorObservers.forEach { $0(error) }
    }
    
    func addObserver(_ observer: @escaping (AppError) -> Void) {
        errorObservers.append(observer)
    }
    
    func removeAllObservers() {
        errorObservers.removeAll()
    }
}

// MARK: - Result Extensions
extension Result {
    func handle(
        _ handler: ErrorHandler = .shared,
        transform: (Error) -> AppError = { AppError.unknown($0) }
    ) {
        if case .failure(let error) = self {
            handler.handle(transform(error))
        }
    }
}

// MARK: - View Extensions
import SwiftUI

struct ErrorAlert: ViewModifier {
    @Binding var error: AppError?
    
    func body(content: Content) -> some View {
        content
            .alert(
                "Error",
                isPresented: Binding(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                ),
                presenting: error
            ) { _ in
                Button("OK") {
                    error = nil
                }
            } message: { error in
                if let suggestion = error.recoverySuggestion {
                    Text("\(error.localizedDescription)\n\n\(suggestion)")
                } else {
                    Text(error.localizedDescription)
                }
            }
    }
}

extension View {
    func errorAlert(error: Binding<AppError?>) -> some View {
        modifier(ErrorAlert(error: error))
    }
} 
