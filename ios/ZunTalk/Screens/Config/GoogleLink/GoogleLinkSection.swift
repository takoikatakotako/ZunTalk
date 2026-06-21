import SwiftUI

/// 設定画面の「Google連携」セクション。
/// Gmail / カレンダー連携の開始・解除と、連携状態を表示する。
struct GoogleLinkSection: View {
    @ObservedObject private var auth = GoogleAuthManager.shared
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        Section {
            if auth.isLinked {
                HStack {
                    Label("Google", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Spacer()
                    Text(auth.linkedEmail ?? "")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Button(role: .destructive) {
                    auth.unlink()
                } label: {
                    Label("連携を解除", systemImage: "link.badge.minus")
                }
            } else {
                Button {
                    Task { await linkGoogle() }
                } label: {
                    HStack {
                        Label("Googleと連携", systemImage: "link")
                        Spacer()
                        if auth.isLinking {
                            ProgressView()
                        }
                    }
                }
                .disabled(auth.isLinking)
            }
        } header: {
            Text("連携")
        } footer: {
            Text("Gmail とカレンダーの読み取りに使います。トークンはこの端末内にのみ保存され、サーバーには送られません。")
        }
        .alert("連携エラー", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "不明なエラーが発生したのだ")
        }
    }

    private func linkGoogle() async {
        do {
            try await auth.link()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
