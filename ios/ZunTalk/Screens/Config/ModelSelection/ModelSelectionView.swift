import SwiftUI

struct ModelSelectionView: View {
    @StateObject private var viewModel = ModelSelectionViewModel()

    var body: some View {
        List {
            Section {
                ForEach(AIModelType.allCases, id: \.self) { modelType in
                    let isAvailable = isModelTypeAvailable(modelType)

                    Button(action: {
                        if isAvailable {
                            viewModel.selectModel(modelType)
                        }
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: modelType.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(isAvailable ? .blue : .gray)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(modelType.displayName)
                                        .foregroundColor(isAvailable ? .primary : .gray)
                                        .font(.body)

                                    if modelType == .foundationModels {
                                        Text("iOS 26+")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.2))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                    }
                                }

                                Text(modelType.description)
                                    .foregroundColor(.secondary)
                                    .font(.caption)

                                if !isAvailable && modelType == .foundationModels {
                                    Text("お使いのデバイスでは利用できません")
                                        .foregroundColor(.red)
                                        .font(.caption2)
                                }
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
                    .disabled(!isAvailable)
                }
            } header: {
                Text("AIモデルを選択")
            } footer: {
                Text("選択したモデルが会話に使用されます。Foundation Modelsは完全無料でプライバシー重視のオンデバイスAIです。")
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

    private func isModelTypeAvailable(_ modelType: AIModelType) -> Bool {
        return modelType.isAvailable
    }
}

#Preview {
    NavigationStack {
        ModelSelectionView()
    }
}
