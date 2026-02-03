import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ModelSelectionView: View {
    @StateObject private var viewModel = ModelSelectionViewModel()
    @State private var showUnsupportedDeviceAlert = false

    var body: some View {
        List {
            Section {
                ForEach(AIModelType.allCases, id: \.self) { modelType in
                    let isAvailable = isModelTypeAvailable(modelType)

                    Button(action: {
                        if modelType == .foundationModels {
                            // iOS 26+でもデバイスがApple Intelligence非対応の場合をチェック
                            if #available(iOS 26.0, *) {
                                checkDeviceSupportAndSelect(modelType)
                            }
                        } else {
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
        }
        .navigationTitle("モデル選択")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.updateAPIKeyStatus()
        }
        .alert("デバイス非対応", isPresented: $showUnsupportedDeviceAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("お使いのデバイスはApple Intelligenceに対応していないため、Foundation Modelsを使用できません。\n\n対応デバイス:\n• iPhone 15 Pro / Pro Max以降\n• iPad（M1以降）\n• Mac（M1以降）")
        }
    }

    private func isModelTypeAvailable(_ modelType: AIModelType) -> Bool {
        return modelType.isAvailable
    }

    @available(iOS 26.0, *)
    private func checkDeviceSupportAndSelect(_ modelType: AIModelType) {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            // デバイス対応OK
            viewModel.selectModel(modelType)
        case .unavailable:
            // デバイス非対応
            showUnsupportedDeviceAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        ModelSelectionView()
    }
}
