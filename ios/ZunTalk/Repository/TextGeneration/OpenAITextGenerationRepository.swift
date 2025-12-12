import Foundation

class OpenAITextGenerationRepository: TextGenerationRepository {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func generateResponse(inputs: [ChatMessage]) async throws -> String {
        // Lambda APIではAPIキーは不要（Lambda側で管理）
        // ただし、互換性のため空チェックは残す

        let url = URL(string: APIConfig.chatEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = LambdaChatRequest(
            messages: inputs,
            model: "gpt-4o-mini",
            maxTokens: 500
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw OpenAITextGenerationError.encodingError
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    print("Lambda API Error: \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("Error Response: \(errorString)")
                    }
                    throw OpenAITextGenerationError.apiError(httpResponse.statusCode)
                }
            }

            let chatResponse = try JSONDecoder().decode(LambdaChatResponse.self, from: data)
            return chatResponse.message.content
        } catch {
            if error is OpenAITextGenerationError {
                throw error
            } else if error is DecodingError {
                throw OpenAITextGenerationError.decodingError
            } else {
                throw OpenAITextGenerationError.networkError(error)
            }
        }
    }
}
