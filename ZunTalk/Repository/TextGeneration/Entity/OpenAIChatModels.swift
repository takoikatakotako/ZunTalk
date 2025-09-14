import Foundation

// MARK: - Request/Response Models
//
//struct OpenAIChatRequest: Codable {
//    let model: String
//    let messages: [ChatMessage]
//    let max_tokens: Int
//    let temperature: Double
//}
//
//struct OpenAIChatResponse: Codable {
//    let id: String
//    let choices: [ChatChoice]
//}
//
//struct ChatChoice: Codable {
//    let message: ChatMessage?
//    let finish_reason: String?
//}

// MARK: - Responses API Models

struct OpenAIResponsesRequest: Codable {
    let model: String
    let input: [ChatMessage]
//    let instructions: String?
//    let temperature: Double?
}
//
//struct OpenAIResponsesResponse: Codable {
//    let id: String
//    let output: [OpenAIResponsesResponseOutput]
////    let model: String
////    let created_at: String
////    let status: String
////    let usage: ResponseUsage?
//}
//
////struct ResponseUsage: Codable {
////    let prompt_tokens: Int?
////    let completion_tokens: Int?
////    let total_tokens: Int?
////}
//
//
//struct OpenAIResponsesResponseOutput: Codable {
//    let content: [OpenAIResponsesResponseOutputContent]
//}
//
//
//struct OpenAIResponsesResponseOutputContent: Codable {
//    let text: String
//}
//
//







struct OpenAIResponsesResponse: Decodable {
    let id: String
    let output: [OpenAIResponsesOutputResponse]
}

enum OpenAIResponsesOutputType: String, Decodable {
    case message
    case reasoning
}

enum OpenAIResponsesOutputResponse: Decodable {
    case message(OpenAIResponsesOutputMessageResponse)
    case reasoning(OpenAIResponsesReasoningResponse)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(OpenAIResponsesOutputType.self, forKey: .type)

        switch type {
        case .message:
            let message = try OpenAIResponsesOutputMessageResponse(from: decoder)
            self = .message(message)
        case .reasoning:
            let reasoning = try OpenAIResponsesReasoningResponse(from: decoder)
            self = .reasoning(reasoning)
        }
    }
}

struct OpenAIResponsesOutputMessageResponse: Decodable {
    let id: String
    let type: OpenAIResponsesOutputType
    let content: [OpenAIResponsesOutputMessageContentResponse]
}


struct OpenAIResponsesReasoningResponse: Decodable {
    let id: String
    let type: OpenAIResponsesOutputType
}


enum OpenAIResponsesOutputMessageContentType: String, Decodable {
    case output_text
    case refusal
}

enum OpenAIResponsesOutputMessageContentResponse: Decodable {
    case outputText(OpenAIResponsesOutputMessageContentOutputTextResponse)
    case refusal(OpenAIResponsesOutputMessageContentRefusalResponse)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(OpenAIResponsesOutputMessageContentType.self, forKey: .type)

        switch type {
        case .output_text:
            let outputText = try OpenAIResponsesOutputMessageContentOutputTextResponse(from: decoder)
            self = .outputText(outputText)
        case .refusal:
            let refusal = try OpenAIResponsesOutputMessageContentRefusalResponse(from: decoder)
            self = .refusal(refusal)
        }
    }
}

struct OpenAIResponsesOutputMessageContentOutputTextResponse: Decodable {
    let type: OpenAIResponsesOutputMessageContentType
    let text: String
}

struct OpenAIResponsesOutputMessageContentRefusalResponse: Decodable {
    let type: OpenAIResponsesOutputMessageContentType
    let refusal: String
}
    
    
    
