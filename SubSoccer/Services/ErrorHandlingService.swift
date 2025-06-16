import SwiftUI
import Foundation

/// Service for centralized error handling with user-friendly messages
@MainActor
class ErrorHandlingService: ObservableObject {
    static let shared = ErrorHandlingService()
    
    @Published var currentError: AppError?
    @Published var isShowingError = false
    
    private init() {}
    
    func handle(_ error: Error, context: String = "") {
        let appError = AppError.from(error, context: context)
        currentError = appError
        isShowingError = true
        
        // Log error for debugging
        print("❌ Error in \(context): \(error)")
    }
    
    func handleAsync(_ operation: @escaping () async throws -> Void, context: String = "") {
        Task {
            do {
                try await operation()
            } catch {
                await MainActor.run {
                    handle(error, context: context)
                }
            }
        }
    }
    
    func dismissError() {
        currentError = nil
        isShowingError = false
    }
}

// MARK: - App Error Types

struct AppError: Identifiable, LocalizedError {
    let id = UUID()
    let type: ErrorType
    let originalError: Error?
    let context: String
    let retryAction: (() async -> Void)?
    
    var errorDescription: String? {
        switch type {
        case .coreData(let operation):
            return "Failed to \(operation). Please try again."
        case .network(let operation):
            return "Network error during \(operation). Check your connection and try again."
        case .imageProcessing:
            return "Failed to process image. Please try with a different image."
        case .fileSystem(let operation):
            return "File operation '\(operation)' failed. Please try again."
        case .validation(let message):
            return message
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
    
    var recoverySuggestion: String? {
        switch type {
        case .coreData:
            return "Try restarting the app if the problem persists."
        case .network:
            return "Check your internet connection and try again."
        case .imageProcessing:
            return "Make sure the image is in a supported format (JPEG, PNG)."
        case .fileSystem:
            return "Make sure you have enough storage space."
        case .validation:
            return "Please correct the highlighted fields and try again."
        case .unknown:
            return "Contact support if this error continues to occur."
        }
    }
    
    var canRetry: Bool {
        return retryAction != nil
    }
    
    static func from(_ error: Error, context: String = "") -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        let errorType: ErrorType
        
        if error is DecodingError || error is EncodingError {
            errorType = .fileSystem("data processing")
        } else if (error as NSError).domain == "NSCocoaErrorDomain" {
            if (error as NSError).code == 134_030 { // Core Data validation error
                errorType = .validation("Please check your input and try again")
            } else {
                errorType = .coreData(context.isEmpty ? "save data" : context)
            }
        } else if (error as NSError).domain == "NSURLErrorDomain" {
            errorType = .network(context.isEmpty ? "network operation" : context)
        } else {
            errorType = .unknown
        }
        
        return AppError(
            type: errorType,
            originalError: error,
            context: context,
            retryAction: nil
        )
    }
}

enum ErrorType {
    case coreData(String)
    case network(String)
    case imageProcessing
    case fileSystem(String)
    case validation(String)
    case unknown
}

// MARK: - Error Handling View Modifiers

struct ErrorAlert: ViewModifier {
    @StateObject private var errorService = ErrorHandlingService.shared
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorService.isShowingError, presenting: errorService.currentError) { error in
                if error.canRetry {
                    Button("Retry") {
                        Task {
                            await error.retryAction?()
                        }
                        errorService.dismissError()
                    }
                }
                
                Button("OK") {
                    errorService.dismissError()
                }
            } message: { error in
                VStack(alignment: .leading, spacing: 8) {
                    if let description = error.errorDescription {
                        Text(description)
                    }
                    
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
    }
}

extension View {
    func handleErrors() -> some View {
        self.modifier(ErrorAlert())
    }
}

// MARK: - Async Error Handling

struct AsyncErrorHandler<Content: View>: View {
    let content: Content
    let operation: () async throws -> Void
    let context: String
    
    @State private var isLoading = false
    @StateObject private var errorService = ErrorHandlingService.shared
    
    init(context: String = "", @ViewBuilder content: () -> Content, operation: @escaping () async throws -> Void) {
        self.content = content()
        self.operation = operation
        self.context = context
    }
    
    var body: some View {
        content
            .disabled(isLoading)
            .task {
                isLoading = true
                errorService.handleAsync(operation, context: context)
                isLoading = false
            }
    }
}

// MARK: - Retry Mechanism

struct RetryButton: View {
    let action: () async throws -> Void
    let context: String
    let label: String
    
    @State private var isRetrying = false
    @StateObject private var errorService = ErrorHandlingService.shared
    
    init(_ label: String, context: String = "", action: @escaping () async throws -> Void) {
        self.label = label
        self.context = context
        self.action = action
    }
    
    var body: some View {
        Button(action: retry) {
            HStack {
                if isRetrying {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text(label)
            }
        }
        .disabled(isRetrying)
    }
    
    private func retry() {
        Task {
            isRetrying = true
            errorService.handleAsync(action, context: context)
            isRetrying = false
        }
    }
}

// MARK: - Safe Async Operations

extension View {
    func safeAsync<T>(
        _ operation: @escaping () async throws -> T,
        context: String = "",
        onSuccess: @escaping (T) -> Void = { _ in }
    ) -> some View {
        self.task {
            do {
                let result = try await operation()
                await MainActor.run {
                    onSuccess(result)
                }
            } catch {
                await MainActor.run {
                    ErrorHandlingService.shared.handle(error, context: context)
                }
            }
        }
    }
}

// MARK: - Form Validation

struct ValidatedField: View {
    let title: String
    @Binding var text: String
    let validation: (String) -> String?
    
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.primaryText)
            
            TextField(title, text: $text)
                .textFieldStyle(AppTextFieldStyle())
                .onChange(of: text) { _, newValue in
                    errorMessage = validation(newValue)
                }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Common Validations

struct Validations {
    static func notEmpty(_ value: String) -> String? {
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "This field is required" : nil
    }
    
    static func jerseyNumber(_ value: String) -> String? {
        guard let number = Int(value), number > 0, number <= 99 else {
            return "Jersey number must be between 1 and 99"
        }
        return nil
    }
    
    static func teamName(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Team name is required"
        }
        if trimmed.count < 2 {
            return "Team name must be at least 2 characters"
        }
        return nil
    }
    
    static func playerName(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Player name is required"
        }
        if trimmed.count < 2 {
            return "Player name must be at least 2 characters"
        }
        return nil
    }
}