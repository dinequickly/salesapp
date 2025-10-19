import Foundation

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingFailed(Error)
    case encodingFailed
    case fileNotFound
}

final class NetworkClient {
    static let shared = NetworkClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    @discardableResult
    func fetchConversations(userId: String) async throws -> [ConversationPreview] {
        guard var components = URLComponents(url: Constants.Endpoint.listConversations, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "user_id", value: userId)]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)

        do {
            return try decoder.decode([ConversationPreview].self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    func fetchAnalysis(userId: String, sessionId: String) async throws -> ConversationAnalysis {
        guard var components = URLComponents(url: Constants.Endpoint.analysis, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "session_id", value: sessionId)
        ]

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)

        do {
            return try decoder.decode(ConversationAnalysis.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    func uploadVideo(fileURL: URL, userId: String, duration: TimeInterval) async throws -> ConversationPreview {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NetworkError.fileNotFound
        }

        var request = URLRequest(url: Constants.Endpoint.upload)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try buildMultipartBody(fileURL: fileURL,
                                          userId: userId,
                                          duration: duration,
                                          boundary: boundary)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        do {
            return try decoder.decode(ConversationPreview.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    private func buildMultipartBody(fileURL: URL,
                                    userId: String,
                                    duration: TimeInterval,
                                    boundary: String) throws -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        func append(_ string: String) {
            if let data = string.data(using: .utf8) {
                body.append(data)
            }
        }

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"user_id\"\(lineBreak)\(lineBreak)")
        append("\(userId)\(lineBreak)")

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"duration\"\(lineBreak)\(lineBreak)")
        append(String(duration))
        append(lineBreak)

        let filename = fileURL.lastPathComponent
        let fileData = try Data(contentsOf: fileURL)
        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"video\"; filename=\"\(filename)\"\(lineBreak)")
        append("Content-Type: video/quicktime\(lineBreak)\(lineBreak)")
        body.append(fileData)
        append(lineBreak)

        append("--\(boundary)--\(lineBreak)")
        return body
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}
