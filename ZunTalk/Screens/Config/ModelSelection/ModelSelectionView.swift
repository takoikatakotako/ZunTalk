import SwiftUI

struct ModelSelectionView: View {
    @StateObject private var viewModel = ModelSelectionViewModel()

    var body: some View {
        List {
            Section {
                ForEach(AIModelType.allCases, id: \.self) { modelType in
                    Button(action: {
                        viewModel.selectModel(modelType)
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: modelType.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(modelType.displayName)
                                    .foregroundColor(.primary)
                                    .font(.body)

                                Text(modelType.description)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }

                            Spacer()

                            if viewModel.selectedModelType == modelType {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("AIモデルを選択")
            } footer: {
                Text("選択したモデルが会話に使用されます。無料サーバーは広告が表示されますが、料金はかかりません。")
            }

            if viewModel.selectedModelType == .openAI {
                Section {
                    NavigationLink(destination: OpenAIAPIKeySettingView()) {
                        HStack {
                            Label("APIキーを設定", systemImage: "key.fill")
                            Spacer()
                            if viewModel.hasOpenAIAPIKey {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                } footer: {
                    Text("OpenAIを使用するには、APIキーの設定が必要です。")
                }
            }
        }
        .navigationTitle("モデル選択")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.updateAPIKeyStatus()
        }
    }
}

#Preview {
    NavigationStack {
        ModelSelectionView()
    }
}
