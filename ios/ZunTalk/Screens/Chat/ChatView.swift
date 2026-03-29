import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isPlaying: viewModel.playingMessageId == message.id,
                                onReplay: {
                                    viewModel.replayVoice(for: message)
                                }
                            )
                            .id(message.id)
                        }

                        if viewModel.isLoading && !viewModel.isPlayingVoice {
                            HStack {
                                TypingIndicatorView()
                                    .padding(.leading, 16)
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                if viewModel.isConversationEnded {
                    Text("会話が終了しました")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else if viewModel.isPlayingVoice {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                            .symbolEffect(.variableColor.iterative, isActive: true)
                        Text("ずんだもんが話しています...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                } else {
                    TextField("メッセージを入力", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .disabled(viewModel.isLoading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .onSubmit {
                            viewModel.sendMessage()
                        }

                    Button(action: {
                        viewModel.sendMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(sendButtonColor)
                    }
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationTitle("ずんだもん")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    private var sendButtonColor: Color {
        let isEmpty = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (isEmpty || viewModel.isLoading) ? Color(.systemGray4) : .blue
    }
}

// MARK: - Message Bubble

private struct MessageBubbleView: View {
    let message: ChatViewModel.DisplayMessage
    let isPlaying: Bool
    let onReplay: () -> Void

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
                .background(message.role == .user ? Color.blue : Color(.systemGray5))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            if message.role == .assistant {
                Button(action: onReplay) {
                    Group {
                        if isPlaying {
                            Image(systemName: "waveform")
                                .foregroundStyle(.green)
                                .symbolEffect(.variableColor.iterative, isActive: true)
                        } else {
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(Color(.systemGray3))
                        }
                    }
                    .font(.system(size: 26))
                    .frame(width: 30, height: 30)
                }
                .disabled(isPlaying)

                Spacer(minLength: 20)
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Typing Indicator

private struct TypingIndicatorView: View {
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
        ChatView()
    }
}

