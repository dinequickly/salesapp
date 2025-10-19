import Foundation

extension Error {
    var displayMessage: String {
        if let networkError = self as? NetworkError {
            switch networkError {
            case .serverError(let status, let message):
                return message ?? "Server error (\(status))."
            case .invalidURL:
                return "Invalid request."
            case .invalidResponse:
                return "Unexpected response from server."
            case .decodingFailed:
                return "Could not read server response."
            case .encodingFailed:
                return "Failed to encode request."
            case .fileNotFound:
                return "Recording missing for upload."
            }
        }
        return localizedDescription
    }
}
