package service

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/takoikatakotako/ZunTalk/backend/model"
)

type OpenAIService struct {
	apiKey string
	client *http.Client
}

func NewOpenAIService(apiKey string) *OpenAIService {
	return &OpenAIService{
		apiKey: apiKey,
		client: &http.Client{},
	}
}

type openAIRequest struct {
	Model       string          `json:"model"`
	Messages    []model.Message `json:"messages"`
	MaxTokens   int             `json:"max_tokens,omitempty"`
	Temperature float64         `json:"temperature,omitempty"`
}

type openAIResponse struct {
	Choices []struct {
		Message model.Message `json:"message"`
	} `json:"choices"`
	Usage struct {
		TotalTokens int `json:"total_tokens"`
	} `json:"usage"`
}

func (s *OpenAIService) CreateChatCompletion(req *model.ChatRequest) (*model.ChatResponse, error) {
	// デフォルト値の設定
	modelName := req.Model
	if modelName == "" {
		modelName = "gpt-4o-mini"
	}

	maxTokens := req.MaxTokens
	if maxTokens == 0 {
		maxTokens = 500
	}

	// OpenAI APIリクエストの構築
	openAIReq := openAIRequest{
		Model:       modelName,
		Messages:    req.Messages,
		MaxTokens:   maxTokens,
		Temperature: 0.7,
	}

	jsonData, err := json.Marshal(openAIReq)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// HTTPリクエストの作成
	httpReq, err := http.NewRequest("POST", "https://api.openai.com/v1/chat/completions", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+s.apiKey)

	// リクエストの送信
	resp, err := s.client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	// レスポンスの読み取り
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("OpenAI API error (status %d): %s", resp.StatusCode, string(body))
	}

	// レスポンスのパース
	var openAIResp openAIResponse
	if err := json.Unmarshal(body, &openAIResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	if len(openAIResp.Choices) == 0 {
		return nil, fmt.Errorf("no choices in response")
	}

	return &model.ChatResponse{
		Message:    openAIResp.Choices[0].Message,
		TokensUsed: openAIResp.Usage.TotalTokens,
	}, nil
}
