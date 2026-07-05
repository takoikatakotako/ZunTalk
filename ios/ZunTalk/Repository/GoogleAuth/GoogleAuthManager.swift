import Foundation
import UIKit
import GoogleSignIn

/// Google（Gmail / Calendar）連携を管理する。
///
/// アクセストークン/リフレッシュトークンは GoogleSignIn が端末内に安全に保持し、
/// **サーバーには一切渡さない**。Gmail / Calendar API は端末から直接叩く（エージェント設計の前提）。
@MainActor
final class GoogleAuthManager: ObservableObject {
    static let shared = GoogleAuthManager()

    /// 連携中アカウントのメールアドレス（nil なら未連携）。
    @Published private(set) var linkedEmail: String?
    /// 連携処理中フラグ（UI のスピナー用）。
    @Published private(set) var isLinking = false

    var isLinked: Bool { linkedEmail != nil }

    /// 端末から Gmail / Calendar を読むためのスコープ（読み取りのみ）。
    static let scopes = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/calendar.readonly"
    ]

    private init() {}

    /// アプリ起動時に前回のサインインを復元する。
    func restore() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, _ in
            self?.linkedEmail = user?.profile?.email
        }
    }

    /// Google と連携する（サインイン＋Gmail/Calendar スコープ付与）。
    func link() async throws {
        guard let presenting = Self.topViewController() else {
            throw GoogleAuthError.noPresenter
        }
        isLinking = true
        defer { isLinking = false }

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presenting,
            hint: nil,
            additionalScopes: Self.scopes
        )

        // 必要なスコープがすべて許可されたか確認する。
        let granted = Set(result.user.grantedScopes ?? [])
        guard Set(Self.scopes).isSubset(of: granted) else {
            GIDSignIn.sharedInstance.signOut()
            throw GoogleAuthError.scopeNotGranted
        }
        linkedEmail = result.user.profile?.email
    }

    /// 連携を解除する。
    func unlink() {
        GIDSignIn.sharedInstance.signOut()
        linkedEmail = nil
    }

    /// 端末側で Gmail / Calendar API を叩くためのアクセストークン（必要に応じて自動更新）。
    func accessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw GoogleAuthError.notLinked
        }
        let refreshed = try await user.refreshTokensIfNeeded()
        return refreshed.accessToken.tokenString
    }

    /// SwiftUI から提示用の最前面 UIViewController を取得する。
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

enum GoogleAuthError: Error, LocalizedError {
    case noPresenter
    case scopeNotGranted
    case notLinked

    var errorDescription: String? {
        switch self {
        case .noPresenter:
            return "画面の取得に失敗したのだ"
        case .scopeNotGranted:
            return "Gmail / カレンダーの権限が許可されなかったのだ"
        case .notLinked:
            return "Google と連携されていないのだ"
        }
    }
}
