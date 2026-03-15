package service

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"time"

	"github.com/takoikatakotako/ZunTalk/backend/model"
)

const (
	maxRetries     = 3
	initialBackoff = 1 * time.Second
	maxBackoff     = 16 * time.Second
	httpTimeout    = 30 * time.Second
)

type OpenAIService struct {
	apiKey string
	client *http.Client
}

func NewOpenAIService(apiKey string) *OpenAIService {
	return &OpenAIService{
		apiKey: apiKey,
		client: &http.Client{
			Timeout: httpTimeout,
		},
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

	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			backoff := calculateBackoff(attempt)
			log.Printf("OpenAI API リトライ %d/%d (待機: %v)", attempt, maxRetries, backoff)
			time.Sleep(backoff)
		}

		resp, err := s.doRequest(jsonData)
		if err != nil {
			// リトライ不要なエラーは即座に返す
			if _, ok := err.(*nonRetryableError); ok {
				return nil, err
			}
			lastErr = err
			log.Printf("OpenAI API リクエストエラー (attempt %d): %v", attempt+1, err)
			continue
		}

		return resp, nil
	}

	return nil, fmt.Errorf("OpenAI API failed after %d retries: %w", maxRetries+1, lastErr)
}

func (s *OpenAIService) doRequest(jsonData []byte) (*model.ChatResponse, error) {
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
		apiErr := fmt.Errorf("OpenAI API error (status %d): %s", resp.StatusCode, string(body))
		if isRetryableStatus(resp.StatusCode) {
			return nil, apiErr
		}
		// リトライ不要なエラー（400, 401, 403等）は即座に返す
		return nil, &nonRetryableError{err: apiErr}
	}

	// レスポンスのパース
	var openAIResp openAIResponse
	if err := json.Unmarshal(body, &openAIResp); err != nil {
		return nil, &nonRetryableError{err: fmt.Errorf("failed to unmarshal response: %w", err)}
	}

	if len(openAIResp.Choices) == 0 {
		return nil, &nonRetryableError{err: fmt.Errorf("no choices in response")}
	}

	return &model.ChatResponse{
		Message:    openAIResp.Choices[0].Message,
		TokensUsed: openAIResp.Usage.TotalTokens,
	}, nil
}

func isRetryableStatus(statusCode int) bool {
	switch statusCode {
	case http.StatusTooManyRequests,
		http.StatusInternalServerError,
		http.StatusBadGateway,
		http.StatusServiceUnavailable,
		http.StatusGatewayTimeout:
		return true
	default:
		return false
	}
}

func calculateBackoff(attempt int) time.Duration {
	backoff := time.Duration(float64(initialBackoff) * math.Pow(2, float64(attempt-1)))
	if backoff > maxBackoff {
		backoff = maxBackoff
	}
	return backoff
}

// nonRetryableError はリトライ不要なエラーを表す
type nonRetryableError struct {
	err error
}

func (e *nonRetryableError) Error() string {
	return e.err.Error()
}

func (e *nonRetryableError) Unwrap() error {
	return e.err
}
