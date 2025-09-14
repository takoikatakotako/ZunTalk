import Foundation

class OpenAITextGenerationRepository: TextGenerationRepository {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/responses"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    let prompt = """
        あなたはずんだの妖精のずんだもんです。語尾に「なのだ」をつけ、親しみやすく楽しい口調で話してください。
        今は電話がかかってきて受け取ったところから会話を始めます。
        最初のセリフは必ず「電話を受けた感のある挨拶」にしてください。
        例: 「もしもし〜？ずんだもんなのだ！」、「はいは〜い、ずんだもんなのだ！」、「お電話ありがとうなのだ！」など。
        例を参考にしつつ、毎回少し違う言い回しにしてください。
        暴力的・攻撃的・不快な発言はしないでください。
        """
    
//    func generateResponse(userMessage: String) async throws -> String {
//        let combinedInput = "\(prompt)\n\nUser: \(userMessage)"
//        return try await generateResponseWithInput(input: combinedInput)
//    }
//    
    func generateResponse(inputs: [ChatMessage]) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAITextGenerationError.invalidAPIKey
        }

        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = OpenAIResponsesRequest(
            model: "gpt-4o",
            input: inputs,
//            instructions: nil,
//            temperature: 0.9
        )

        do {
            let xxx = try JSONEncoder().encode(requestBody)
            print(String(data: xxx, encoding: .utf8))
            
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw OpenAITextGenerationError.encodingError
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            
            print(String(data: data, encoding: .utf8))

            
            
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    print("OpenAI API Error: \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("Error Response: \(errorString)")
                    }
                    throw OpenAITextGenerationError.apiError(httpResponse.statusCode)
                }
            }

            let responsesResponse = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
            
            
            // message の text をオプショナルで取り出す
            var firstMessageText: String? = nil
            for output in responsesResponse.output {
                switch output {
                case let .message(msg):
                    // msg.content から outputText ケースだけ探す
                    for content in msg.content {
                        switch content {
                        case let .outputText(textContent):
                            firstMessageText = textContent.text
                            break  // 最初の text が見つかったらループを抜ける
                        case .refusal:
                            continue
                        }
                    }
                    if firstMessageText != nil {
                        break  // 最初の message が見つかったらループを抜ける
                    }
                case .reasoning:
                    continue
                }
            }
            
            guard let firstMessageText = firstMessageText else {
                throw OpenAITextGenerationError.noResponse
            }

            return firstMessageText
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
