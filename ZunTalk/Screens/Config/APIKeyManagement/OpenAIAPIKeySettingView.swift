import SwiftUI

struct OpenAIAPIKeySettingView: View {
    @StateObject private var viewModel = OpenAIAPIKeySettingViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSaveSuccess = false

    var body: some View {
        List {
            Section {
                HStack {
                    if viewModel.showPassword {
                        TextField("sk-proj-...", text: $viewModel.apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("sk-proj-...", text: $viewModel.apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                    }

                    Button(action: {
                        viewModel.togglePasswordVisibility()
                    }) {
                        Image(systemName: viewModel.showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("OpenAI APIキー")
            } footer: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("OpenAIのAPIキーを入力してください。APIキーは「sk-proj-」で始まります。")

                    Text("APIキーはアプリ内でのみ使われ、外部サーバーには送信されません。APIキーはKeychainに安全に保存されます。")
                        .foregroundColor(.secondary)

                    Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                        HStack {
                            Text("APIキーを取得する")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.footnote)
                    }
                }
            }

            Section {
                Button(action: {
                    viewModel.saveAPIKey()
                    showSaveSuccess = true
                }) {
                    HStack {
                        Spacer()
                        Text("保存")
                            .font(.body.weight(.semibold))
                        Spacer()
                    }
                }
                .disabled(viewModel.isSaveButtonDisabled)
            }
        }
        .navigationTitle("OpenAI APIキー設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadAPIKey()
        }
        .alert("保存しました", isPresented: $showSaveSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("OpenAI APIキーが正常に保存されました。")
        }
    }
}

#Preview {
    NavigationStack {
        OpenAIAPIKeySettingView()
    }
}
