package service

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"

	"github.com/takoikatakotako/ZunTalk/backend/model"
)

func newTestRequest() *model.ChatRequest {
	return &model.ChatRequest{
		Messages: []model.Message{
			{Role: "user", Content: "こんにちは"},
		},
	}
}

func newSuccessResponse() openAIResponse {
	return openAIResponse{
		Choices: []struct {
			Message model.Message `json:"message"`
		}{
			{Message: model.Message{Role: "assistant", Content: "やっほー！"}},
		},
		Usage: struct {
			TotalTokens int `json:"total_tokens"`
		}{TotalTokens: 10},
	}
}

func TestCreateChatCompletion_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(newSuccessResponse())
	}))
	defer server.Close()

	svc := newTestService(server.URL)
	resp, err := svc.CreateChatCompletion(newTestRequest())

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Message.Content != "やっほー！" {
		t.Errorf("expected 'やっほー！', got '%s'", resp.Message.Content)
	}
}

func TestCreateChatCompletion_RetryOn429(t *testing.T) {
	var callCount atomic.Int32

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		count := callCount.Add(1)
		if count <= 2 {
			w.WriteHeader(http.StatusTooManyRequests)
			w.Write([]byte(`{"error": "rate limited"}`))
			return
		}
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(newSuccessResponse())
	}))
	defer server.Close()

	svc := newTestService(server.URL)
	resp, err := svc.CreateChatCompletion(newTestRequest())

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Message.Content != "やっほー！" {
		t.Errorf("expected 'やっほー！', got '%s'", resp.Message.Content)
	}
	if callCount.Load() != 3 {
		t.Errorf("expected 3 calls, got %d", callCount.Load())
	}
}

func TestCreateChatCompletion_RetryOn500(t *testing.T) {
	var callCount atomic.Int32

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		count := callCount.Add(1)
		if count <= 1 {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(`{"error": "internal server error"}`))
			return
		}
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(newSuccessResponse())
	}))
	defer server.Close()

	svc := newTestService(server.URL)
	resp, err := svc.CreateChatCompletion(newTestRequest())

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected response, got nil")
	}
	if callCount.Load() != 2 {
		t.Errorf("expected 2 calls, got %d", callCount.Load())
	}
}

func TestCreateChatCompletion_NoRetryOn400(t *testing.T) {
	var callCount atomic.Int32

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		callCount.Add(1)
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(`{"error": "bad request"}`))
	}))
	defer server.Close()

	svc := newTestService(server.URL)
	_, err := svc.CreateChatCompletion(newTestRequest())

	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if callCount.Load() != 1 {
		t.Errorf("expected 1 call (no retry), got %d", callCount.Load())
	}
}

func TestCreateChatCompletion_NoRetryOn401(t *testing.T) {
	var callCount atomic.Int32

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		callCount.Add(1)
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte(`{"error": "unauthorized"}`))
	}))
	defer server.Close()

	svc := newTestService(server.URL)
	_, err := svc.CreateChatCompletion(newTestRequest())

	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if callCount.Load() != 1 {
		t.Errorf("expected 1 call (no retry), got %d", callCount.Load())
	}
}

func TestCreateChatCompletion_ExhaustsRetries(t *testing.T) {
	var callCount atomic.Int32

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		callCount.Add(1)
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte(`{"error": "service unavailable"}`))
	}))
	defer server.Close()

	svc := newTestService(server.URL)
	_, err := svc.CreateChatCompletion(newTestRequest())

	if err == nil {
		t.Fatal("expected error after exhausting retries")
	}
	// 初回 + 3リトライ = 4回
	if callCount.Load() != 4 {
		t.Errorf("expected 4 calls, got %d", callCount.Load())
	}
}

// newTestService はテスト用のOpenAIServiceを作成（APIエンドポイントを差し替え可能にするため、
// doRequestのURLをテストサーバーに向ける）
func newTestService(baseURL string) *OpenAIService {
	svc := NewOpenAIService("test-api-key")
	// テスト用にHTTPクライアントのTransportをカスタマイズしてURLを書き換え
	svc.client.Transport = &urlRewriteTransport{
		baseURL:   baseURL,
		transport: http.DefaultTransport,
	}
	return svc
}

// urlRewriteTransport はリクエストのURLをテストサーバーに書き換えるTransport
type urlRewriteTransport struct {
	baseURL   string
	transport http.RoundTripper
}

func (t *urlRewriteTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	req.URL.Scheme = "http"
	req.URL.Host = ""
	req.URL.Path = "/"
	newURL := t.baseURL + "/"
	newReq, _ := http.NewRequest(req.Method, newURL, req.Body)
	newReq.Header = req.Header
	return t.transport.RoundTrip(newReq)
}
