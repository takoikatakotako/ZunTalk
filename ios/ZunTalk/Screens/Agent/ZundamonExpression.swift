import Foundation

/// ずんだもんの表情。エージェントの状態に応じて切り替える。
enum ZundamonExpression {
    /// 待機中。
    case idle
    /// 考え中（エージェント実行・ツール取得中）。
    case thinking
    /// 喋っている（音声再生中）。
    case talking

    /// 表示する画像アセット名。
    ///
    /// TODO: 表情画像が揃ったら差し替える（例: zunda-idle / zunda-thinking / zunda-talking）。
    /// 現状はアセットが thumbnail のみのため、すべて thumbnail で代用する。
    var imageName: String {
        switch self {
        case .idle:
            return "thumbnail"
        case .thinking:
            return "thumbnail"
        case .talking:
            return "thumbnail"
        }
    }
}
