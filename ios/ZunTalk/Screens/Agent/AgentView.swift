import SwiftUI
import UIKit

/// ずんだもんエージェント画面。上部にずんだもん画像（表情変化）、下部にチャット入力。
struct AgentView: View {
    @StateObject private var viewModel = AgentViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var modelStatus: ZundamonModelStatus = .loading
    @State private var keyboardHeight: CGFloat = 0
    @State private var safeAreaBottom: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            roomBackground
                .ignoresSafeArea()

            GeometryReader { proxy in
                characterLayer(height: characterViewportHeight(proxy.size.height))
                    .onAppear { safeAreaBottom = proxy.safeAreaInsets.bottom }
                    .onChange(of: proxy.safeAreaInsets.bottom) { _, newValue in
                        safeAreaBottom = newValue
                    }
            }

            dialogueOverlay

            inputOverlay
                .padding(.bottom, inputBottomPadding)
                .zIndex(10)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.easeOut(duration: 0.18), value: isInputFocused)
        .animation(.easeOut(duration: 0.22), value: keyboardHeight)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            keyboardHeight = keyboardOverlap(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .navigationTitle("ずんだもん")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.cleanup() }
    }

    // MARK: - Subviews

    private var roomBackground: some View {
        GeometryReader { proxy in
            Image("agent-room-background")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }

    private func characterLayer(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Zundamon3DView(
                expression: .neutral,
                speaking: viewModel.isPlayingVoice,
                framing: .fullBody,
                status: $modelStatus
            )
            .frame(height: min(height * 0.76, 720))
            .frame(maxWidth: .infinity)
            .offset(y: 24)
            Spacer(minLength: 0)
        }
        .padding(.top, 40)
        .allowsHitTesting(false)
    }

    private func characterViewportHeight(_ geometryHeight: CGFloat) -> CGFloat {
        max(geometryHeight, UIScreen.main.bounds.height)
    }

    private var dialoguePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Circle()
                    .fill(Color(red: 0.56, green: 0.86, blue: 0.34))
                    .frame(width: 10, height: 10)
                Text("ずんだもん")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
            }

            Text(dialogueText)
                .font(.system(size: 22, weight: .semibold))
                .lineSpacing(6)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.24, green: 0.28, blue: 0.19).opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
    }

    private var dialogueText: String {
        switch modelStatus {
        case .loading:
            return "Loading..."
        case .failed:
            return "モデルの読み込みに失敗したのだ"
        case .loaded:
            break
        }
        if viewModel.isLoading {
            return "考え中なのだ…"
        }
        if let assistantMessage = viewModel.messages.last(where: { $0.role == .assistant }) {
            return assistantMessage.content
        }
        return "こんばんは。今日は何を話すのだ？"
    }

    private var remainingText: some View {
        Text("残り3回")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white.opacity(0.42))
            .frame(maxWidth: .infinity)
    }

    private var dialogueOverlay: some View {
        VStack(spacing: 8) {
            dialoguePanel
            remainingText
        }
        .padding(.horizontal, 16)
        .padding(.bottom, effectiveSafeAreaBottom + 80)
    }

    private var inputOverlay: some View {
        inputBar
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("話してみて…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .disabled(viewModel.isLoading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit { sendMessage() }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(sendButtonColor)
                    .frame(width: 36, height: 36)
            }
            .disabled(isSendDisabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }

    private var isSendDisabled: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading
    }

    private func sendMessage() {
        viewModel.send()
        isInputFocused = false
        keyboardHeight = 0
    }

    private var sendButtonColor: Color {
        isSendDisabled ? Color(.systemGray4) : .blue
    }

    private var inputBottomPadding: CGFloat {
        guard isInputFocused else {
            return effectiveSafeAreaBottom + 2
        }

        if keyboardHeight > 0 {
            return max(0, keyboardHeight - effectiveSafeAreaBottom) + 6
        }

        let fallbackKeyboardHeight: CGFloat = 300
        return fallbackKeyboardHeight + 6
    }

    private var effectiveSafeAreaBottom: CGFloat {
        max(safeAreaBottom, windowSafeAreaBottom)
    }

    private var windowSafeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0
    }

    private func keyboardOverlap(from notification: Notification) -> CGFloat {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }

        let screenHeight = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .screen.bounds.height ?? UIScreen.main.bounds.height

        return max(0, screenHeight - frame.minY)
    }
}

// MARK: - Background

private struct RoomCeiling: View {
    var body: some View {
        Canvas { context, size in
            let base = Path(CGRect(origin: .zero, size: size))
            context.fill(base, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.57, green: 0.47, blue: 0.33),
                    Color(red: 0.34, green: 0.25, blue: 0.17)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            for i in 0..<7 {
                let x = size.width * CGFloat(i) / 6
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: size.width / 2 + (x - size.width / 2) * 0.45, y: size.height))
                context.stroke(line, with: .color(.black.opacity(0.22)), lineWidth: 2)
            }
        }
    }
}

private struct RoomWall: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.76, green: 0.70, blue: 0.56),
                    Color(red: 0.50, green: 0.44, blue: 0.33)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .top) {
                wallFrame(width: 72, height: 210)
                    .padding(.leading, 12)
                    .padding(.top, 70)
                Spacer()
                VStack(spacing: 18) {
                    wallFrame(width: 128, height: 92)
                    wallFrame(width: 92, height: 126)
                }
                .padding(.trailing, 24)
                .padding(.top, 55)
            }

            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.29, green: 0.21, blue: 0.13).opacity(0.62))
                    .frame(height: 10)
            }
        }
    }

    private func wallFrame(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(red: 0.84, green: 0.78, blue: 0.61).opacity(0.58))
            .frame(width: width, height: height)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.28), lineWidth: 2))
            .overlay {
                VStack(spacing: 8) {
                    ForEach(0..<3) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.black.opacity(0.18))
                            .frame(height: 3)
                            .padding(.horizontal, 12)
                    }
                }
            }
    }
}

private struct RoomFloor: View {
    var body: some View {
        Canvas { context, size in
            let rect = Path(CGRect(origin: .zero, size: size))
            context.fill(rect, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.58, green: 0.48, blue: 0.31),
                    Color(red: 0.30, green: 0.25, blue: 0.18)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            for i in 0..<8 {
                let y = size.height * CGFloat(i) / 7
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y + CGFloat(i) * 8))
                context.stroke(line, with: .color(.black.opacity(0.18)), lineWidth: 1)
            }
        }
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
