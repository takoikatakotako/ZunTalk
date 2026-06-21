import SwiftUI

/// ずんだもんエージェント画面。上部にずんだもん画像（表情変化）、下部にチャット入力。
struct AgentView: View {
    @StateObject private var viewModel = AgentViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // ずんだもん（表情）
            zundamonHeader

            Divider()

            // 会話
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            AgentMessageBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            HStack {
                                AgentTypingIndicator()
                                    .padding(.leading, 16)
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // 入力
            inputBar
        }
        .navigationTitle("ずんだもんエージェント")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.cleanup() }
    }

    // MARK: - Subviews

    private var zundamonHeader: some View {
        VStack(spacing: 6) {
            Image(viewModel.expression.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .scaleEffect(viewModel.isPlayingVoice ? 1.03 : 1.0)
                .animation(
                    viewModel.isPlayingVoice
                        ? .easeInOut(duration: 0.4).repeatForever(autoreverses: true)
                        : .default,
                    value: viewModel.isPlayingVoice
                )

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color("call-background").opacity(0.3))
    }

    private var statusText: String {
        switch viewModel.expression {
        case .idle: return "話しかけてみてなのだ！"
        case .thinking: return "考え中なのだ…"
        case .talking: return "おしゃべり中なのだ♪"
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("例: 予定とメールを確認して", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .disabled(viewModel.isLoading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit { viewModel.send() }

            Button {
                viewModel.send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(sendButtonColor)
            }
            .disabled(isSendDisabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var isSendDisabled: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading
    }

    private var sendButtonColor: Color {
        isSendDisabled ? Color(.systemGray4) : .purple
    }
}

// MARK: - Message Bubble

private struct AgentMessageBubble: View {
    let message: AgentViewModel.DisplayMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                Image(.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            }

            if message.role == .user {
                Spacer(minLength: 60)
            }

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.role == .user ? Color.purple : Color(.systemGray5))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Typing Indicator

private struct AgentTypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(.systemGray3))
                    .frame(width: 8, height: 8)
                    .offset(y: animating ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear { animating = true }
    }
}

#Preview {
    NavigationStack {
        AgentView()
    }
}
