# ---------- build ----------
FROM golang:1.24 AS build

WORKDIR /src

# 依存だけ先にキャッシュ
COPY go.mod go.sum ./
RUN go mod download

COPY . .
# 静的バイナリをビルド
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/server .

# ---------- runtime ----------
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /
COPY --from=build /out/server /server

# Cloud Run は PORT を注入する（デフォルト 8080）
EXPOSE 8080
USER nonroot:nonroot

ENTRYPOINT ["/server"]
