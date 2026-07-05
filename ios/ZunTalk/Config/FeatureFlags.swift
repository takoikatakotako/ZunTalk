import Foundation

/// 機能の出し分けフラグ。
enum FeatureFlags {
    /// エージェント機能（3Dずんだもんとの会話 + Gmail/Calendar 連携）を有効にするか。
    ///
    /// Google の OAuth 審査（同意画面の verification）が通るまで、
    /// 本番（Production）ビルドでは UI ごと非表示にする。
    /// Development ビルドでは従来どおり動く（ハッカソンのデモ用）。
    /// 審査通過後はこのフラグを `true` 固定に変えるだけでよい。
    #if DEBUG
    static let agentModeEnabled = true
    #else
    static let agentModeEnabled = false
    #endif
}
