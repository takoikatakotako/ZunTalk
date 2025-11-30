package model

// Message represents a chat message
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// ChatRequest represents a chat completion request
type ChatRequest struct {
	Messages  []Message `json:"messages"`
	Model     string    `json:"model"`
	MaxTokens int       `json:"maxTokens"`
}

// ChatResponse represents a chat completion response
type ChatResponse struct {
	Message    Message `json:"message"`
	TokensUsed int     `json:"tokensUsed"`
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}
