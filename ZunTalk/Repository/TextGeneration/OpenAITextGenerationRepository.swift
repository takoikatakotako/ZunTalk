import Foundation

class OpenAITextGenerationRepository: TextGenerationRepository {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generateResponse(userMessage: String) async throws -> String {
        let systemMessage = ChatMessage(role: .system, content: "あなたは関西弁で話すずんだもんです。語尾に「なのだ」をつけて、親しみやすく楽しく会話してください。")
        let userMessage = ChatMessage(role: .user, content: userMessage)
        
        return try await generateResponse(messages: [systemMessage, userMessage])
    }
    
    func generateResponse(messages: [ChatMessage]) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAITextGenerationError.invalidAPIKey
        }
        
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = OpenAIChatRequest(
            model: "gpt-3.5-turbo",
            messages: messages,
            max_tokens: 300,
            temperature: 0.9
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
                    print("OpenAI API Error: \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("Error Response: \(errorString)")
                    }
                    throw OpenAITextGenerationError.apiError(httpResponse.statusCode)
                }
            }
            
            let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            
            guard let firstChoice = chatResponse.choices.first,
                  let message = firstChoice.message else {
                throw OpenAITextGenerationError.noResponse
            }
            
            return message.content
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