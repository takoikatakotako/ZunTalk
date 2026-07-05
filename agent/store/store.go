// Package store は Firestore への永続化を担当する。
// Cloud Run のサービスアカウント（ADC）でキーレス認証する。
package store

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/takoikatakotako/ZunTalk/agent/model"
)

const (
	devicesCollection = "devices"
	callsCollection   = "scheduledCalls"

	// dueGraceWindow を超えて滞留した予約は missed にする
	//（障害復帰後に古い着信が大量発火するのを防ぐ）。
	dueGraceWindow = 10 * time.Minute
)

var (
	// ErrNotFound は対象ドキュメントが存在しない。
	ErrNotFound = errors.New("store: not found")
	// ErrForbidden は deviceId が一致しない（他端末の予約は操作不可）。
	ErrForbidden = errors.New("store: device mismatch")
	// ErrConflict は状態遷移が競合した（既に送信済み・キャンセル済みなど）。
	ErrConflict = errors.New("store: status conflict")
	// ErrLimitExceeded は端末あたりの予約上限に達した。
	ErrLimitExceeded = errors.New("store: pending call limit exceeded")
)

// Device は devices コレクションのドキュメント。
type Device struct {
	VoIPToken     string     `firestore:"voipToken"`
	APNSEnv       string     `firestore:"apnsEnv"`
	BundleID      string     `firestore:"bundleId"`
	InvalidatedAt *time.Time `firestore:"invalidatedAt"`
	CreatedAt     time.Time  `firestore:"createdAt"`
	UpdatedAt     time.Time  `firestore:"updatedAt"`
}

// ScheduledCall は scheduledCalls コレクションのドキュメント。
type ScheduledCall struct {
	ID          string    `firestore:"-"`
	DeviceID    string    `firestore:"deviceId"`
	ScheduledAt time.Time `firestore:"scheduledAt"`
	Status      string    `firestore:"status"`
	LastError   string    `firestore:"lastError"`
	CreatedAt   time.Time `firestore:"createdAt"`
	UpdatedAt   time.Time `firestore:"updatedAt"`
}

// Store は Firestore クライアントのラッパー。
type Store struct {
	client *firestore.Client
}

// New は Firestore クライアントを初期化する。
func New(ctx context.Context, projectID string) (*Store, error) {
	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("store: failed to init firestore client: %w", err)
	}
	return &Store{client: client}, nil
}

// Close はクライアントを閉じる。
func (s *Store) Close() error {
	return s.client.Close()
}

// UpsertDevice は端末情報を登録・更新する（冪等）。
func (s *Store) UpsertDevice(ctx context.Context, deviceID string, req model.RegisterDeviceRequest) error {
	ref := s.client.Collection(devicesCollection).Doc(deviceID)
	now := time.Now().UTC()
	return s.client.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		snap, err := tx.Get(ref)
		createdAt := now
		if err == nil {
			var existing Device
			if err := snap.DataTo(&existing); err == nil && !existing.CreatedAt.IsZero() {
				createdAt = existing.CreatedAt
			}
		} else if status.Code(err) != codes.NotFound {
			return err
		}
		return tx.Set(ref, Device{
			VoIPToken:     req.VoIPToken,
			APNSEnv:       req.APNSEnv,
			BundleID:      req.BundleID,
			InvalidatedAt: nil, // トークン再登録で無効化フラグは解除する
			CreatedAt:     createdAt,
			UpdatedAt:     now,
		})
	})
}

// GetDevice は端末情報を取得する。
func (s *Store) GetDevice(ctx context.Context, deviceID string) (*Device, error) {
	snap, err := s.client.Collection(devicesCollection).Doc(deviceID).Get(ctx)
	if err != nil {
		if status.Code(err) == codes.NotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	var d Device
	if err := snap.DataTo(&d); err != nil {
		return nil, err
	}
	return &d, nil
}

// MarkDeviceInvalid は APNs に 410 (Unregistered) と言われた端末を無効化する。
func (s *Store) MarkDeviceInvalid(ctx context.Context, deviceID string) error {
	now := time.Now().UTC()
	_, err := s.client.Collection(devicesCollection).Doc(deviceID).Update(ctx, []firestore.Update{
		{Path: "invalidatedAt", Value: now},
		{Path: "updatedAt", Value: now},
	})
	return err
}

// UpdateDeviceAPNSEnv は端末の APNs 環境を更新する。
// BadDeviceToken フォールバックで実際に通った環境を学習するために使う。
func (s *Store) UpdateDeviceAPNSEnv(ctx context.Context, deviceID, apnsEnv string) error {
	_, err := s.client.Collection(devicesCollection).Doc(deviceID).Update(ctx, []firestore.Update{
		{Path: "apnsEnv", Value: apnsEnv},
		{Path: "updatedAt", Value: time.Now().UTC()},
	})
	return err
}

// CreateCall は電話の予約を作成する。端末あたりの未発火予約数に上限を設ける。
func (s *Store) CreateCall(ctx context.Context, deviceID string, scheduledAt time.Time) (*ScheduledCall, error) {
	// 未発火の予約数を確認（equality のみのクエリなので複合インデックス不要）
	pending, err := s.client.Collection(callsCollection).
		Where("deviceId", "==", deviceID).
		Where("status", "==", model.CallStatusScheduled).
		Limit(model.MaxPendingCallsPerDevice).
		Documents(ctx).GetAll()
	if err != nil {
		return nil, err
	}
	if len(pending) >= model.MaxPendingCallsPerDevice {
		return nil, ErrLimitExceeded
	}

	now := time.Now().UTC()
	call := ScheduledCall{
		DeviceID:    deviceID,
		ScheduledAt: scheduledAt.UTC(),
		Status:      model.CallStatusScheduled,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	ref, _, err := s.client.Collection(callsCollection).Add(ctx, call)
	if err != nil {
		return nil, err
	}
	call.ID = ref.ID
	return &call, nil
}

// ListCalls は端末の予約一覧を返す（予約時刻昇順）。
func (s *Store) ListCalls(ctx context.Context, deviceID string) ([]ScheduledCall, error) {
	// deviceId の equality のみで取得し、並び替えはメモリ上で行う
	//（orderBy を付けると複合インデックスが必要になるため）。
	snaps, err := s.client.Collection(callsCollection).
		Where("deviceId", "==", deviceID).
		Limit(100).
		Documents(ctx).GetAll()
	if err != nil {
		return nil, err
	}
	calls := make([]ScheduledCall, 0, len(snaps))
	for _, snap := range snaps {
		var c ScheduledCall
		if err := snap.DataTo(&c); err != nil {
			continue
		}
		c.ID = snap.Ref.ID
		calls = append(calls, c)
	}
	sort.Slice(calls, func(i, j int) bool { return calls[i].ScheduledAt.Before(calls[j].ScheduledAt) })
	return calls, nil
}

// CancelCall は予約をキャンセルする。deviceID が一致し status が scheduled の場合のみ。
func (s *Store) CancelCall(ctx context.Context, callID, deviceID string) error {
	ref := s.client.Collection(callsCollection).Doc(callID)
	return s.client.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		snap, err := tx.Get(ref)
		if err != nil {
			if status.Code(err) == codes.NotFound {
				return ErrNotFound
			}
			return err
		}
		var c ScheduledCall
		if err := snap.DataTo(&c); err != nil {
			return err
		}
		if c.DeviceID != deviceID {
			return ErrForbidden
		}
		if c.Status != model.CallStatusScheduled {
			return ErrConflict
		}
		return tx.Update(ref, []firestore.Update{
			{Path: "status", Value: model.CallStatusCanceled},
			{Path: "updatedAt", Value: time.Now().UTC()},
		})
	})
}

// ListUpcomingCalls は「期限が到来済み〜horizon 以内に到来する」予約を返す（claim はしない）。
// 毎分ポーリングでも秒精度で発火させるため、dispatcher は先読みして発火時刻まで待つ。
func (s *Store) ListUpcomingCalls(ctx context.Context, now time.Time, horizon time.Duration) ([]ScheduledCall, error) {
	now = now.UTC()
	snaps, err := s.client.Collection(callsCollection).
		Where("status", "==", model.CallStatusScheduled).
		Where("scheduledAt", ">", now.Add(-dueGraceWindow)).
		Where("scheduledAt", "<=", now.Add(horizon)).
		Limit(50).
		Documents(ctx).GetAll()
	if err != nil {
		return nil, err
	}

	calls := make([]ScheduledCall, 0, len(snaps))
	for _, snap := range snaps {
		var call ScheduledCall
		if err := snap.DataTo(&call); err != nil {
			continue
		}
		call.ID = snap.Ref.ID
		calls = append(calls, call)
	}
	return calls, nil
}

// ClaimCall は予約をトランザクションで scheduled → sending に遷移させる。
// 既に状態が変わっていた場合（キャンセル済み・別実行が claim 済み）は ErrConflict。
// 送信の直前に claim することで、発火待ちの間のキャンセルも反映される。
func (s *Store) ClaimCall(ctx context.Context, callID string) (*ScheduledCall, error) {
	ref := s.client.Collection(callsCollection).Doc(callID)
	var call ScheduledCall
	err := s.client.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		fresh, err := tx.Get(ref)
		if err != nil {
			return err
		}
		if err := fresh.DataTo(&call); err != nil {
			return err
		}
		if call.Status != model.CallStatusScheduled {
			return ErrConflict
		}
		return tx.Update(ref, []firestore.Update{
			{Path: "status", Value: model.CallStatusSending},
			{Path: "updatedAt", Value: time.Now().UTC()},
		})
	})
	if err != nil {
		return nil, err
	}
	call.ID = ref.ID
	call.Status = model.CallStatusSending
	return &call, nil
}

// MarkCallResult は送信結果を記録する。
func (s *Store) MarkCallResult(ctx context.Context, callID, callStatus, lastError string) error {
	_, err := s.client.Collection(callsCollection).Doc(callID).Update(ctx, []firestore.Update{
		{Path: "status", Value: callStatus},
		{Path: "lastError", Value: lastError},
		{Path: "updatedAt", Value: time.Now().UTC()},
	})
	return err
}

// MarkMissedCalls は猶予時間を過ぎても未発火の予約を missed にする。
func (s *Store) MarkMissedCalls(ctx context.Context, now time.Time) (int, error) {
	now = now.UTC()
	snaps, err := s.client.Collection(callsCollection).
		Where("status", "==", model.CallStatusScheduled).
		Where("scheduledAt", "<=", now.Add(-dueGraceWindow)).
		Limit(100).
		Documents(ctx).GetAll()
	if err != nil {
		return 0, err
	}
	count := 0
	for _, snap := range snaps {
		_, err := snap.Ref.Update(ctx, []firestore.Update{
			{Path: "status", Value: model.CallStatusMissed},
			{Path: "updatedAt", Value: time.Now().UTC()},
		})
		if err == nil {
			count++
		}
	}
	return count, nil
}
