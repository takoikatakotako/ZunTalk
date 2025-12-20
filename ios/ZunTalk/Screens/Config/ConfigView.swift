import SwiftUI

struct ConfigView: View {
    @State private var showResetAlert = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "不明"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "不明"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section("AI設定") {
                NavigationLink(destination: ModelSelectionView()) {
                    Label("モデル選択", systemImage: "brain")
                }

                NavigationLink(destination: APIKeyManagementView()) {
                    Label("APIキー管理", systemImage: "key")
                }

                NavigationLink(destination: Text("プロンプト設定画面")) {
                    Label("プロンプト設定", systemImage: "text.bubble")
                }
            }

            Section("サポート") {
                NavigationLink(destination: Text("お問い合わせ画面")) {
                    Label("お問い合わせ", systemImage: "envelope")
                }

                NavigationLink(destination: Text("開発者情報")) {
                    Label("開発者情報", systemImage: "person.circle")
                }

                Link(destination: URL(string: "https://x.com/takoikatakotako")!) {
                    HStack {
                        Label("開発者のXアカウント", systemImage: "link")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("法的情報") {
                NavigationLink(destination: Text("ライセンス情報")) {
                    Label("ライセンス", systemImage: "doc.text")
                }
            }

            Section("アプリ情報") {
                HStack {
                    Label("バージョン", systemImage: "info.circle")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button(action: {
                    showResetAlert = true
                }) {
                    HStack {
                        Label("すべての設定をリセット", systemImage: "arrow.counterclockwise")
                        Spacer()
                    }
                }
                .foregroundColor(.red)
            } footer: {
                Text("すべての設定をデフォルト値に戻します。APIキーやモデル選択などがリセットされます。")
            }
        }
        .navigationTitle("設定")
        .alert("すべての設定をリセット", isPresented: $showResetAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("リセット", role: .destructive) {
                resetAllSettings()
                // アプリを終了して再起動を促す
                exit(0)
            }
        } message: {
            Text("すべての設定がデフォルト値に戻ります。この操作は取り消せません。\nアプリは自動的に終了します。")
        }
    }

    private func resetAllSettings() {
        // APIキーを削除
        UserSettings.shared.deleteOpenAIAPIKey()

        // モデル選択をデフォルトに戻す
        UserSettings.shared.selectedModelType = .freeServer

        // オンボーディングをリセット
        let repository = UserDefaultsRepository()
        repository.resetAll()

        // 他の設定もここに追加
    }
}

#Preview {
    ConfigView()
}
