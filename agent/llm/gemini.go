package llm

import (
	"context"
	"fmt"

	"google.golang.org/genai"
)

// Gemini は Vertex AI 経由で Gemini を呼ぶ薄いラッパ。
// 認証は ADC（Application Default Credentials）/ サービスアカウントによるキーレス。
type Gemini struct {
	client *genai.Client
	model  string
}

// NewGemini は Vertex AI バックエンドの Gemini クライアントを生成する。
func NewGemini(ctx context.Context, projectID, location, model string) (*Gemini, error) {
	client, err := genai.NewClient(ctx, &genai.ClientConfig{
		Project:  projectID,
		Location: location,
		Backend:  genai.BackendVertexAI,
	})
	if err != nil {
		return nil, fmt.Errorf("genai クライアントの生成に失敗: %w", err)
	}
	return &Gemini{client: client, model: model}, nil
}

// GenerateText は system/user プロンプトからテキストを生成する（responder 用）。
func (g *Gemini) GenerateText(ctx context.Context, systemPrompt, userPrompt string) (string, error) {
	cfg := &genai.GenerateContentConfig{
		SystemInstruction: genai.Text(systemPrompt)[0],
		Temperature:       ptr(float32(0.7)),
	}
	resp, err := g.client.Models.GenerateContent(ctx, g.model, genai.Text(userPrompt), cfg)
	if err != nil {
		return "", fmt.Errorf("テキスト生成に失敗: %w", err)
	}
	return resp.Text(), nil
}

// GenerateJSON は ResponseSchema で構造を強制した JSON 文字列を生成する（planner 用）。
func (g *Gemini) GenerateJSON(ctx context.Context, systemPrompt, userPrompt string, schema *genai.Schema) (string, error) {
	cfg := &genai.GenerateContentConfig{
		SystemInstruction: genai.Text(systemPrompt)[0],
		Temperature:       ptr(float32(0.2)),
		ResponseMIMEType:  "application/json",
		ResponseSchema:    schema,
	}
	resp, err := g.client.Models.GenerateContent(ctx, g.model, genai.Text(userPrompt), cfg)
	if err != nil {
		return "", fmt.Errorf("JSON生成に失敗: %w", err)
	}
	return resp.Text(), nil
}

func ptr[T any](v T) *T { return &v }
