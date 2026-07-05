// Package middleware は Echo 用の認証ミドルウェアを提供する。
package middleware

import (
	"log/slog"
	"net/http"
	"strings"

	"github.com/labstack/echo/v4"
	"google.golang.org/api/idtoken"

	"github.com/takoikatakotako/ZunTalk/agent/model"
)

const googleIssuer = "https://accounts.google.com"

// SchedulerOIDC は Cloud Scheduler が付与する OIDC トークンを検証する。
// Cloud Run は /agent を公開するため allUsers のままにしており、
// /internal/dispatch はこのミドルウェアで Scheduler の SA からの呼び出しに限定する。
//
// expectedSA / audience が空の場合はローカル開発用に検証をスキップする
//（apiKeyMiddleware と同じ流儀）。
func SchedulerOIDC(expectedSA, audience string) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			if expectedSA == "" || audience == "" {
				slog.Warn("SCHEDULER_SERVICE_ACCOUNT is empty; /internal/dispatch OIDC verification is DISABLED (local dev only)")
				return next(c)
			}

			authz := c.Request().Header.Get("Authorization")
			token, ok := strings.CutPrefix(authz, "Bearer ")
			if !ok || token == "" {
				return unauthorized(c, "missing bearer token")
			}

			payload, err := idtoken.Validate(c.Request().Context(), token, audience)
			if err != nil {
				return unauthorized(c, "invalid token: "+err.Error())
			}
			if payload.Issuer != googleIssuer {
				return unauthorized(c, "unexpected issuer")
			}
			email, _ := payload.Claims["email"].(string)
			verified, _ := payload.Claims["email_verified"].(bool)
			if !verified || email != expectedSA {
				return unauthorized(c, "unexpected caller: "+email)
			}

			return next(c)
		}
	}
}

func unauthorized(c echo.Context, reason string) error {
	slog.Warn("Rejected dispatch request", "reason", reason)
	return c.JSON(http.StatusUnauthorized, model.ErrorResponse{
		Code:    "UNAUTHORIZED",
		Message: "認証に失敗しました",
	})
}
