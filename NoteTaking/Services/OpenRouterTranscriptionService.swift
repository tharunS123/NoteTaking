import Foundation

enum TranscriptionServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case decodingError
    case serviceError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenRouter API key is missing. Add it to your Info.plist as OPENROUTER_API_KEY."
        case .invalidResponse:
            return "Received an unexpected response from the transcription service."
        case .decodingError:
            return "Unable to decode the response from the transcription service."
        case .serviceError(let message):
            return message
        }
    }
}

struct NoteSummary: Equatable {
    let transcript: String
    let notes: String
}

struct OpenRouterTranscriptionService {
    private let session: URLSession
    private let transcriptionModel = "openai/gpt-oss-120b"
    private let summarizationModel = "openai/gpt-oss-120b"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func transcribeAndSummarize(from audioURL: URL) async throws -> NoteSummary {
        let transcript = try await transcribeAudio(from: audioURL)
        let notes = try await summarize(transcript: transcript)
        return NoteSummary(transcript: transcript, notes: notes)
    }

    private func transcribeAudio(from audioURL: URL) async throws -> String {
        let apiKey = try fetchAPIKey()
        let url = URL(string: "https://openrouter.ai/api/v1")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let audioData = try Data(contentsOf: audioURL)
        let multipartData = makeMultipartBody(boundary: boundary,
                                              model: transcriptionModel,
                                              fileName: audioURL.lastPathComponent,
                                              fileData: audioData)
        request.httpBody = multipartData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = decodeServiceError(from: data) {
                throw TranscriptionServiceError.serviceError(apiError)
            }
            throw TranscriptionServiceError.invalidResponse
        }

        do {
            let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            return result.text
        } catch {
            print("This is a message printed to the Xcode console.")
            throw TranscriptionServiceError.decodingError
        }
    }

    private func summarize(transcript: String) async throws -> String {
        let apiKey = try fetchAPIKey()
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let prompt = """
        You are an expert note-taking assistant. Create comprehensive, structured notes from the provided transcript.\n\nRequirements:\n- Start with a one-sentence executive summary.\n- Include a detailed bullet list of key points.\n- Add action items with owners if they exist.\n- Highlight terminology or definitions if mentioned.\n- Conclude with suggested follow-up questions.\n\nTranscript:\n\(transcript)
        """

        let payload = ChatCompletionPayload(model: summarizationModel, messages: [
            .init(role: "system", content: "You transform spoken content into clear, well structured notes for students and professionals."),
            .init(role: "user", content: prompt)
        ], temperature: 0.2)

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = decodeServiceError(from: data) {
                throw TranscriptionServiceError.serviceError(apiError)
            }
            throw TranscriptionServiceError.invalidResponse
        }

        do {
            let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            guard let content = result.choices.first?.message.content else {
                throw TranscriptionServiceError.invalidResponse
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw TranscriptionServiceError.decodingError
        }
    }

    private func fetchAPIKey() throws -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String, !value.isEmpty else {
            throw TranscriptionServiceError.missingAPIKey
        }
        return value
    }

    private func makeMultipartBody(boundary: String, model: String, fileName: String, fileData: Data) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append(lineBreak.data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    private func decodeServiceError(from data: Data) -> String? {
        guard let apiError = try? JSONDecoder().decode(ServiceErrorResponse.self, from: data) else { return nil }
        return apiError.error.message
    }
}

private struct TranscriptionResponse: Decodable {
    let text: String
}

private struct ChatCompletionPayload: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct ServiceErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}
