import SwiftUI

/// エージェント結線の検証用画面。テキストで発話 → plan/results/reply を表示する。
struct AgentTestView: View {
    @StateObject private var viewModel = AgentTestViewModel()

    var body: some View {
        Form {
            Section("メッセージ") {
                TextField("例: 予定とメールを確認して", text: $viewModel.input, axis: .vertical)
                    .lineLimit(1...4)

                Button {
                    Task { await viewModel.send() }
                } label: {
                    HStack {
                        Text("送信")
                        Spacer()
                        if viewModel.isRunning {
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isRunning || viewModel.input.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !viewModel.planText.isEmpty {
                Section("計画（plan）") {
                    Text(viewModel.planText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            if !viewModel.resultsText.isEmpty {
                Section("端末での実行結果（results）") {
                    Text(viewModel.resultsText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            if !viewModel.reply.isEmpty {
                Section("ずんだもんの返答") {
                    Text(viewModel.reply)
                }
            }

            if !viewModel.errorText.isEmpty {
                Section("エラー") {
                    Text(viewModel.errorText)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("エージェント（テスト）")
        .navigationBarTitleDisplayMode(.inline)
    }
}
