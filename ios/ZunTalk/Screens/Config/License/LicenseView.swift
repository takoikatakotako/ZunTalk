import SwiftUI

struct LicenseView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("VOICEVOX:ずんだもん")
                        .font(.headline)

                    Text("音声合成には VOICEVOX:ずんだもん を使用しています。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Link(destination: URL(string: "https://voicevox.hiroshiba.jp/")!) {
                        HStack {
                            Text("VOICEVOX 公式サイト")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://zunko.jp/con_ongen_kiyaku.html")!) {
                        HStack {
                            Text("ずんだもん音源利用ガイドライン")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("音声ライブラリ")
            }

            Section {
                LicenseItemView(
                    name: "VOICEVOX CORE",
                    license: "MIT License",
                    url: "https://github.com/VOICEVOX/voicevox_core",
                    description: "音声合成エンジン"
                )
            } header: {
                Text("オープンソースライブラリ")
            }

            Section {
                LicenseItemView(
                    name: "Open JTalk",
                    license: "BSD-3-Clause License",
                    url: "https://github.com/VOICEVOX/open_jtalk-rs",
                    description: "日本語音声合成システム"
                )

                LicenseItemView(
                    name: "ONNX Runtime",
                    license: "MIT License",
                    url: "https://github.com/microsoft/onnxruntime",
                    description: "機械学習推論エンジン"
                )
            }
        }
        .navigationTitle("ライセンス")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LicenseItemView: View {
    let name: String
    let license: String
    let url: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(license)
                .font(.caption)
                .foregroundColor(.blue)

            Link(destination: URL(string: url)!) {
                HStack {
                    Text("詳細を見る")
                        .font(.caption)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        LicenseView()
    }
}
