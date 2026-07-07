import Foundation

/// 機能の出し分けフラグ。
enum FeatureFlags {
    /// エージェント機能（3Dずんだもんとの会話）を有効にするか。
    /// カレンダーは EventKit を使うため、本番でも Google OAuth 審査なしで利用できる。
    static let agentModeEnabled = true

    /// Gmail 系の Google 連携 UI を有効にするか。
    /// Gmail は Google OAuth のテストモード運用に留めるため Debug 限定にする。
    #if DEBUG
    static let googleLinkEnabled = true
    #else
    static let googleLinkEnabled = false
    #endif
}
