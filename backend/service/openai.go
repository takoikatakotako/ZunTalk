package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/hashicorp/go-retryablehttp"
	"github.com/takoikatakotako/ZunTalk/backend/model"
)

const (
	retryMax     = 3
	retryWaitMin = 1 * time.Second
	retryWaitMax = 16 * time.Second
	httpTimeout  = 30 * time.Second
)

type OpenAIService struct {
	apiKey      string
	retryClient *retryablehttp.Client
}

func NewOpenAIService(apiKey string) *OpenAIService {
	retryClient := retryablehttp.NewClient()
	retryClient.RetryMax = retryMax
	retryClient.RetryWaitMin = retryWaitMin
	retryClient.RetryWaitMax = retryWaitMax
	retryClient.CheckRetry = openAIRetryPolicy
	retryClient.HTTPClient.Timeout = httpTimeout

	return &OpenAIService{
		apiKey:      apiKey,
		retryClient: retryClient,
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

	// retryablehttp用リクエストの作成
	httpReq, err := retryablehttp.NewRequest("POST", "https://api.openai.com/v1/chat/completions", bytes.NewReader(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+s.apiKey)

	// リクエストの送信（リトライはgo-retryablehttpが自動処理）
	resp, err := s.retryClient.Do(httpReq)
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

// openAIRetryPolicy は429と5xxのみリトライする
func openAIRetryPolicy(ctx context.Context, resp *http.Response, err error) (bool, error) {
	// ネットワークエラーはリトライ
	if err != nil {
		return true, nil
	}

	// 429 (Rate Limit) と 5xx はリトライ
	if resp.StatusCode == http.StatusTooManyRequests ||
		resp.StatusCode >= http.StatusInternalServerError {
		return true, nil
	}

	return false, nil
}
