import SwiftUI

struct ConfigView: View {
    var body: some View {
        List {
            Section("アプリ設定") {
                NavigationLink(destination: Text("アプリ設定画面")) {
                    Label("その他アプリ設定", systemImage: "gear")
                }
            }

            Section("サポート") {
                NavigationLink(destination: Text("お問い合わせ画面")) {
                    Label("お問い合わせ", systemImage: "envelope")
                }

                NavigationLink(destination: Text("開発者情報")) {
                    Label("開発者情報", systemImage: "person.circle")
                }

                Link(destination: URL(string: "https://x.com/jumpei_ikegami")!) {
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
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button(action: {
                    // リセット処理
                }) {
                    HStack {
                        Label("リセット", systemImage: "arrow.clockwise")
                        Spacer()
                    }
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("設定")
    }
}

#Preview {
    ConfigView()
}