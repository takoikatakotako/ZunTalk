import Foundation

/// 通話画面の起動モード。
enum CallMode {
    /// 連絡先リストから発信する従来の疑似通話（アプリ内で着信音を鳴らす）。
    case simulated
    /// VoIP push → CallKit 応答から始まる通話（着信音はシステムが鳴らし済み、
    /// AudioSession は CallKit が管理する）。
    case callKit
}
