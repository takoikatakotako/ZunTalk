import SwiftUI

struct APIKeyManagementView: View {
    @StateObject private var viewModel = APIKeyManagementViewModel()
    @State private var showDeleteAlert = false

    var body: some View {
        List {
            Section {
                NavigationLink(destination: OpenAIAPIKeySettingView()) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("OpenAI")
                                .font(.body)

                            if viewModel.hasOpenAIAPIKey {
                                Text("設定済み")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            } else {
                                Text("未設定")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }

                        Spacer()
                    }
                }
            } header: {
                Text("APIキー")
            } footer: {
                Text("各AIサービスのAPIキーを設定できます。APIキーは安全に保存されます。")
            }

            if viewModel.hasOpenAIAPIKey {
                Section {
                    Button(role: .destructive, action: {
                        showDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("OpenAI APIキーを削除")
                        }
                    }
                }
            }
        }
        .navigationTitle("APIキー管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.updateAPIKeyStatus()
        }
        .alert("APIキーを削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                viewModel.deleteOpenAIAPIKey()
            }
        } message: {
            Text("OpenAI APIキーを削除してもよろしいですか？この操作は取り消せません。")
        }
    }
}

#Preview {
    NavigationStack {
        APIKeyManagementView()
    }
}
