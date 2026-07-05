import Foundation
import CoreGraphics

/// ずんだもんの表情。エージェントのライフサイクル状態（待機/考え中）と、
/// 返答の感情（neutral/happy/sad/surprised/troubled）の両方を1つの enum で表す。
enum ZundamonExpression {
    // ライフサイクル状態
    case idle       // 待機中
    case thinking   // 考え中（エージェント実行・ツール取得中）

    // 返答の感情（喋っているとき）
    case neutral
    case happy
    case sad
    case surprised
    case troubled

    /// サーバーの emotion 文字列から、喋っているときの表情を作る。
    static func from(emotion: String?) -> ZundamonExpression {
        switch emotion {
        case "happy":     return .happy
        case "sad":       return .sad
        case "surprised": return .surprised
        case "troubled":  return .troubled
        default:          return .neutral
        }
    }

    /// この表情で使う標準モーフ値。
    var morphWeights: [String: CGFloat] {
        switch self {
        case .idle:
            return ["Fun": 0.45]
        case .neutral:
            return [:]
        case .thinking:
            return ["ジト目1": 0.6]
        case .happy:
            return ["Joy": 1.0]
        case .sad:
            return ["Sorrow": 1.0, "涙": 0.6]
        case .surprised:
            return ["見開き白目": 1.0]
        case .troubled:
            return ["困り眉1": 1.0]
        }
    }

    /// 表示する画像アセット名。
    ///
    /// TODO: 表情画像（または Live2D/3D）が揃ったら差し替える
    /// （例: zunda-idle / zunda-thinking / zunda-happy / zunda-sad ...）。
    /// 現状はアセットが thumbnail のみのため、すべて thumbnail で代用する。
    var imageName: String {
        return "thumbnail"
    }
}
