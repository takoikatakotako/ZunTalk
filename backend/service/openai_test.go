package service

import (
	"context"
	"encoding/json"
	"fmt"
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

func newTestService(baseURL string) *OpenAIService {
	svc := NewOpenAIService("test-api-key")
	// retryClientの内部HTTPClientのTransportを差し替え
	svc.retryClient.HTTPClient.Transport = &urlRewriteTransport{
		baseURL:   baseURL,
		transport: http.DefaultTransport,
	}
	return svc
}

type urlRewriteTransport struct {
	baseURL   string
	transport http.RoundTripper
}

func (t *urlRewriteTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	newReq, _ := http.NewRequest(req.Method, t.baseURL+"/", req.Body)
	newReq.Header = req.Header
	return t.transport.RoundTrip(newReq)
}

func TestCreateChatCompletion_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(newSuccessResponse())
	}))
	defer server.Close()

	resp, err := newTestService(server.URL).CreateChatCompletion(newTestRequest())
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
		if callCount.Add(1) <= 2 {
			w.WriteHeader(http.StatusTooManyRequests)
			w.Write([]byte(`{"error": "rate limited"}`))
			return
		}
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(newSuccessResponse())
	}))
	defer server.Close()

	resp, err := newTestService(server.URL).CreateChatCompletion(newTestRequest())
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
		if callCount.Add(1) <= 1 {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(`{"error": "internal server error"}`))
			return
		}
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(newSuccessResponse())
	}))
	defer server.Close()

	resp, err := newTestService(server.URL).CreateChatCompletion(newTestRequest())
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

	_, err := newTestService(server.URL).CreateChatCompletion(newTestRequest())
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

	_, err := newTestService(server.URL).CreateChatCompletion(newTestRequest())
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if callCount.Load() != 1 {
		t.Errorf("expected 1 call (no retry), got %d", callCount.Load())
	}
}

func TestOpenAIRetryPolicy(t *testing.T) {
	tests := []struct {
		name       string
		statusCode int
		wantRetry  bool
	}{
		{"429 should retry", http.StatusTooManyRequests, true},
		{"500 should retry", http.StatusInternalServerError, true},
		{"502 should retry", http.StatusBadGateway, true},
		{"503 should retry", http.StatusServiceUnavailable, true},
		{"504 should retry", http.StatusGatewayTimeout, true},
		{"400 should not retry", http.StatusBadRequest, false},
		{"401 should not retry", http.StatusUnauthorized, false},
		{"403 should not retry", http.StatusForbidden, false},
		{"200 should not retry", http.StatusOK, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp := &http.Response{StatusCode: tt.statusCode}
			retry, _ := openAIRetryPolicy(context.Background(), resp, nil)
			if retry != tt.wantRetry {
				t.Errorf("got retry=%v, want %v", retry, tt.wantRetry)
			}
		})
	}

	t.Run("network error should retry", func(t *testing.T) {
		retry, _ := openAIRetryPolicy(context.Background(), nil, fmt.Errorf("connection refused"))
		if !retry {
			t.Error("expected retry on network error")
		}
	})
}
