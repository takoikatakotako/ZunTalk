import SwiftUI

/// ずんだもん3Dモデルの表情モーフ調整用画面。
struct ZundamonExpressionDebugView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var expression: ZundamonExpression = .neutral
    @State private var speaking = false
    @State private var modelStatus: ZundamonModelStatus = .loading
    @State private var morphWeights: [String: CGFloat] = [:]
    @State private var outputText = ""
    @State private var manualMorphScale: CGFloat = 1
    @State private var eyeDebugMode: ZundamonEyeDebugMode = .normal
    @State private var eyeDepthOffset: CGFloat = 0
    @State private var suppressNextExpressionSync = false

    private let expressionOptions: [(label: String, value: ZundamonExpression)] = [
        ("idle", .idle),
        ("neutral", .neutral),
        ("thinking", .thinking),
        ("happy", .happy),
        ("sad", .sad),
        ("surprised", .surprised),
        ("troubled", .troubled)
    ]

    private let morphGroups: [(title: String, names: [String])] = [
        ("VRM標準", ["Joy", "Fun", "Angry", "Sorrow", "Blink", "Blink_L", "Blink_R"]),
        ("目", ["普通目2", "普通目3", "ジト目1", "ジト目2", "ジト白目", "見開き白目", "なごみ目", "にっこり", "にっこり2", "まばたき", "キャッチライト", "〇〇", "UU", "＞＜"]),
        ("眉・感情", ["怒り眉", "上がり眉", "困り眉1", "困り眉2", "涙", "汗", "汗2", "ほっぺ", "ほっぺ赤め", "青ざめ", "かげり"]),
        ("口", ["A", "I", "U", "E", "O", "むー", "お", "んー", "んへー", "んあー", "△", "むふ", "ほー", "ほあ", "ほあー"])
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color("call-background").opacity(0.3)
                Zundamon3DView(
                    expression: expression,
                    speaking: speaking,
                    appliesExpressionMorphs: false,
                    manualMorphWeights: activeMorphWeights,
                    manualMorphScale: manualMorphScale,
                    eyeDebugMode: eyeDebugMode,
                    eyeDepthOffset: eyeDepthOffset,
                    status: $modelStatus
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if modelStatus == .loading {
                    ProgressView()
                }
            }
            .frame(height: 330)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("プリセット") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("表情", selection: $expression) {
                                ForEach(expressionOptions, id: \.label) { option in
                                    Text(option.label).tag(option.value)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: expression) { _, newValue in
                                syncSliders(with: newValue)
                            }

                            Toggle("口パク", isOn: $speaking)
                        }
                    }

                    GroupBox("普通顔候補") {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button("候補 A") {
                                    applyCandidate(["Fun": 0.25, "Blink": 0.18])
                                }
                                .buttonStyle(.bordered)

                                Button("候補 B") {
                                    applyCandidate(["Fun": 0.2, "なごみ目": 0.18])
                                }
                                .buttonStyle(.bordered)

                                Button("候補 C") {
                                    applyCandidate(["Fun": 0.2, "にっこり": 0.12])
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    GroupBox("Eye デバッグ") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("表示", selection: $eyeDebugMode) {
                                ForEach(ZundamonEyeDebugMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("モーフ倍率")
                                    Spacer()
                                    Text(String(format: "%.1f", Double(manualMorphScale)))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(manualMorphScale) },
                                        set: { manualMorphScale = CGFloat($0) }
                                    ),
                                    in: 1...8,
                                    step: 0.5
                                )
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Z オフセット")
                                    Spacer()
                                    Text(String(format: "%.3f", Double(eyeDepthOffset)))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(eyeDepthOffset) },
                                        set: { eyeDepthOffset = CGFloat($0) }
                                    ),
                                    in: -0.08...0.08,
                                    step: 0.001
                                )
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button("モーフをリセット") {
                            morphWeights = expression.morphWeights
                            speaking = false
                            outputText = ""
                            manualMorphScale = 1
                            eyeDebugMode = .normal
                            eyeDepthOffset = 0
                        }
                        .buttonStyle(.bordered)

                        Button("決定") {
                            outputText = resultText
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if !outputText.isEmpty {
                        GroupBox("出力") {
                            Text(outputText)
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    ForEach(morphGroups, id: \.title) { group in
                        GroupBox(group.title) {
                            VStack(spacing: 12) {
                                ForEach(group.names, id: \.self) { name in
                                    morphSlider(name)
                                }
                            }
                        }
                    }

                    if !activeMorphWeights.isEmpty {
                        GroupBox("現在の調整値") {
                            Text(debugText)
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("表情確認")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
    }

    private var activeMorphWeights: [String: CGFloat] {
        morphWeights.filter { $0.value > 0.001 }
    }

    private var debugText: String {
        activeMorphWeights
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \(String(format: "%.2f", Double($0.value)))" }
            .joined(separator: "\n")
    }

    private var resultText: String {
        let expressionLabel = expressionOptions.first { $0.value == expression }?.label ?? "unknown"
        let morphText = debugText.isEmpty ? "なし" : debugText
        return """
        expression: \(expressionLabel)
        speaking: \(speaking)
        manualMorphScale: \(String(format: "%.1f", Double(manualMorphScale)))
        eyeDebugMode: \(eyeDebugMode.rawValue)
        eyeDepthOffset: \(String(format: "%.3f", Double(eyeDepthOffset)))
        morphs:
        \(morphText)
        """
    }

    private func applyCandidate(_ weights: [String: CGFloat]) {
        suppressNextExpressionSync = expression != .neutral
        expression = .neutral
        speaking = false
        morphWeights = weights
        outputText = ""
    }

    private func syncSliders(with expression: ZundamonExpression) {
        if suppressNextExpressionSync {
            suppressNextExpressionSync = false
            return
        }
        morphWeights = expression.morphWeights
        outputText = ""
    }

    private func morphSlider(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                Spacer()
                Text(String(format: "%.2f", Double(morphWeights[name, default: 0])))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(morphWeights[name, default: 0]) },
                    set: { morphWeights[name] = CGFloat($0) }
                ),
                in: 0...1,
                step: 0.01
            )
        }
    }
}

#Preview {
    NavigationStack {
        ZundamonExpressionDebugView()
    }
}
