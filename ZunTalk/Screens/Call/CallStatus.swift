import Foundation

enum CallStatus {
    case idle                       // 初期化
    case initializingVoiceVox      // VoiceVoxのセットアップ中
    case requestingPermission      // 音声認識の許可リクエスト中
    case permissionGranted         // 許可取得確認
    case permissionDenied          // 不許可
    case generatingScript          // スクリプト生成中
    case synthesizingVoice         // 音声合成中
    case playingVoice              // 音声再生中
    case recognizingSpeech         // 音声認識中
    case processingResponse        // 音声認識完了後の処理中
    case ended                     // 通話終了
}
