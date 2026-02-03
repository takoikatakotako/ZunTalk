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
            // MARK: - AI設定
            Section("AI設定") {
                NavigationLink(destination: ModelSelectionView()) {
                    Label("モデル選択", systemImage: "brain")
                }
            }

            Section("サポート") {
                Link(destination: URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSfqxPpkdiG7JW5qIiz0pf0oisne4HIJZiL8nkhmPmgFAlRwCA/viewform")!) {
                    HStack {
                        Label("お問い合わせ", systemImage: "envelope")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }

                Link(destination: URL(string: "https://github.com/takoikatakotako/ZunTalk")!) {
                    HStack {
                        Label("GitHub", systemImage: "link")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
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
                Link(destination: URL(string: "https://takoikatakotako.github.io/projects/zuntalk/terms.html")!) {
                    HStack {
                        Label("利用規約", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }

                Link(destination: URL(string: "https://takoikatakotako.github.io/projects/zuntalk/privacy.html")!) {
                    HStack {
                        Label("プライバシーポリシー", systemImage: "hand.raised")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink(destination: LicenseView()) {
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
                Text("すべての設定をデフォルト値に戻します。")
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
