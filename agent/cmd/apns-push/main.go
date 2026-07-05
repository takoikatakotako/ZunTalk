// apns-push は VoIP push を手動で1件送るテスト用 CLI。
// サーバーを立てずに「APNs → 実機着信」の疎通を確認するために使う。
//
// 使い方:
//
//	go run ./cmd/apns-push \
//	  -p8 ~/Downloads/AuthKey_XXXXXXXXXX.p8 \
//	  -key-id XXXXXXXXXX \
//	  -team-id 5RH346BQ66 \
//	  -token <PKPushRegistry の hex トークン> \
//	  -env sandbox \
//	  -topic com.swiswiswift.zuntalk.voip
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/takoikatakotako/ZunTalk/agent/apns"
)

func main() {
	p8Path := flag.String("p8", "", "APNs Auth Key (.p8) のパス")
	keyID := flag.String("key-id", "", "APNs Auth Key の Key ID")
	teamID := flag.String("team-id", "5RH346BQ66", "Apple Developer Team ID")
	token := flag.String("token", "", "VoIP デバイストークン（hex）")
	env := flag.String("env", "sandbox", "APNs 環境 (sandbox|production)")
	topic := flag.String("topic", "com.swiswiswift.zuntalk.voip", "apns-topic（{bundleId}.voip）")
	callID := flag.String("call-id", "", "callId（省略時は現在時刻から生成）")
	flag.Parse()

	if *p8Path == "" || *keyID == "" || *token == "" {
		flag.Usage()
		os.Exit(2)
	}
	if *env != string(apns.EnvSandbox) && *env != string(apns.EnvProduction) {
		log.Fatalf("invalid -env: %s (sandbox|production)", *env)
	}

	p8, err := os.ReadFile(*p8Path)
	if err != nil {
		log.Fatalf("failed to read .p8: %v", err)
	}

	client, err := apns.New(p8, *keyID, *teamID)
	if err != nil {
		log.Fatalf("failed to init APNs client: %v", err)
	}

	id := *callID
	if id == "" {
		id = fmt.Sprintf("manual-%d", time.Now().Unix())
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	if err := client.Send(ctx, *token, apns.Env(*env), *topic, apns.NewVoIPPayload(id)); err != nil {
		log.Fatalf("push failed: %v", err)
	}
	fmt.Printf("push sent: callId=%s env=%s topic=%s\n", id, *env, *topic)
}
