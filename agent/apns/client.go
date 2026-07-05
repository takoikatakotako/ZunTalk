package apns

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Env は APNs の接続先環境。Development ビルドの端末は sandbox、
// App Store / TestFlight ビルドの端末は production のトークンを持つ。
type Env string

const (
	EnvSandbox    Env = "sandbox"
	EnvProduction Env = "production"
)

const (
	hostSandbox    = "https://api.sandbox.push.apple.com"
	hostProduction = "https://api.push.apple.com"

	// Apple はプロバイダトークンの再利用を20〜60分と定めている。
	// 毎回生成すると TooManyProviderTokenUpdates になるため40分キャッシュする。
	tokenTTL = 40 * time.Minute
)

// ErrUnregistered は APNs が 410 (Unregistered) を返した場合のエラー。
// 呼び出し側はこのデバイストークンを無効化するべき。
var ErrUnregistered = errors.New("apns: device token is no longer active")

// Client は APNs へ VoIP push を送るクライアント。
// .p8 の APNs Auth Key（チーム単位・sandbox/production 共用）で ES256 JWT 認証する。
type Client struct {
	key    *ecdsa.PrivateKey
	keyID  string
	teamID string

	httpClient *http.Client

	mu          sync.Mutex
	cachedToken string
	tokenIssued time.Time
}

// New は .p8 ファイルの中身（PEM）から Client を生成する。
func New(p8PEM []byte, keyID, teamID string) (*Client, error) {
	block, _ := pem.Decode(p8PEM)
	if block == nil {
		return nil, errors.New("apns: failed to decode .p8 PEM block")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("apns: failed to parse .p8 private key: %w", err)
	}
	key, ok := parsed.(*ecdsa.PrivateKey)
	if !ok {
		return nil, errors.New("apns: .p8 key is not an ECDSA private key")
	}
	return &Client{
		key:    key,
		keyID:  keyID,
		teamID: teamID,
		// Go の net/http は https に対して自動で HTTP/2 を使う（APNs は HTTP/2 必須）。
		httpClient: &http.Client{Timeout: 10 * time.Second},
	}, nil
}

// VoIPPayload は VoIP push のペイロード。
// VoIP push は通知 UI を持たないため aps は空でよい。
type VoIPPayload struct {
	APS        struct{} `json:"aps"`
	CallID     string   `json:"callId"`
	CallerName string   `json:"callerName"`
}

// NewVoIPPayload はずんだもんからの着信ペイロードを生成する。
func NewVoIPPayload(callID string) VoIPPayload {
	return VoIPPayload{CallID: callID, CallerName: "ずんだもん"}
}

// Send は VoIP push を1件送信する。
//   - deviceToken: PKPushRegistry から得た hex 文字列
//   - env: 端末が登録時に申告した APNs 環境
//   - topic: "{bundleId}.voip"（apns-topic ヘッダにそのまま入る）
//
// APNs が 410 を返した場合は ErrUnregistered を返す。
func (c *Client) Send(ctx context.Context, deviceToken string, env Env, topic string, payload any) error {
	host := hostProduction
	if env == EnvSandbox {
		host = hostSandbox
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("apns: failed to marshal payload: %w", err)
	}

	token, err := c.providerToken()
	if err != nil {
		return err
	}

	url := fmt.Sprintf("%s/3/device/%s", host, deviceToken)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("apns: failed to create request: %w", err)
	}
	req.Header.Set("authorization", "bearer "+token)
	req.Header.Set("apns-topic", topic)
	req.Header.Set("apns-push-type", "voip")
	req.Header.Set("apns-priority", "10")
	// 電話の着信は遅延配信されると意味がないため、即時配信できなければ破棄させる。
	req.Header.Set("apns-expiration", "0")
	req.Header.Set("content-type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("apns: request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		return nil
	}

	respBody, _ := io.ReadAll(resp.Body)
	reason := parseReason(respBody)
	if resp.StatusCode == http.StatusGone {
		return fmt.Errorf("%w (reason=%s)", ErrUnregistered, reason)
	}
	return fmt.Errorf("apns: push rejected: status=%d reason=%s", resp.StatusCode, reason)
}

// providerToken はキャッシュ済みの ES256 JWT を返す。期限切れなら再生成する。
func (c *Client) providerToken() (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.cachedToken != "" && time.Since(c.tokenIssued) < tokenTTL {
		return c.cachedToken, nil
	}

	now := time.Now()
	t := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.MapClaims{
		"iss": c.teamID,
		"iat": now.Unix(),
	})
	t.Header["kid"] = c.keyID

	signed, err := t.SignedString(c.key)
	if err != nil {
		return "", fmt.Errorf("apns: failed to sign provider token: %w", err)
	}
	c.cachedToken = signed
	c.tokenIssued = now
	return signed, nil
}

// parseReason は APNs のエラーレスポンス {"reason":"..."} から reason を取り出す。
func parseReason(body []byte) string {
	var r struct {
		Reason string `json:"reason"`
	}
	if err := json.Unmarshal(body, &r); err != nil || r.Reason == "" {
		return string(body)
	}
	return r.Reason
}
