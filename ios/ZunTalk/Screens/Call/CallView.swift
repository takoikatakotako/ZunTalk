import SwiftUI
import StoreKit

struct CallView: View {
    @StateObject private var viewModel = CallViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(Circle())

                // ステータス表示
                VStack(spacing: 12) {
                    Text(statusText)
                        .foregroundStyle(statusColor)
                        .font(Font.system(size: 18, weight: .semibold))
                        .padding(.top, 24)

                    // 会話時間表示（常に表示）
                    Text(formattedDuration)
                        .foregroundStyle(.gray)
                        .font(Font.system(size: 24, weight: .medium))
                        .padding(.top, 8)

                    if !viewModel.text.isEmpty {
                        Text(viewModel.text)
                            .foregroundStyle(Color.gray)
                            .font(Font.system(size: 24))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }
                }

                Spacer()

                HStack(spacing: 112) {
                    Button(action: {
                        viewModel.requestDismiss()
                    }) {
                        ZStack {
                            Color(.red)
                            Text(.init(systemName: "phone.down.fill"))
                                .foregroundStyle(Color.white)
                                .font(Font.system(size: 48).bold())
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    }

                }
            }
            .padding(.top, 48)
            .padding(.bottom, 24)
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: viewModel.shouldDismiss) { oldValue, newValue in
            if newValue {
                dismiss()
            }
        }
        .onChange(of: viewModel.shouldRequestReview) { oldValue, newValue in
            if newValue {
                requestReview()
            }
        }
    }

    private var statusText: String {
        switch viewModel.status {
        case .idle:
            return "準備中..."
        case .initializingVoiceVox:
            return "音声エンジンを初期化中..."
        case .requestingPermission:
            return "音声認識の許可を確認中..."
        case .permissionGranted:
            return "準備完了"
        case .permissionDenied:
            return "音声認識の許可が必要です"
        case .generatingScript:
            return "返答を考え中..."
        case .synthesizingVoice:
            return "音声を生成中..."
        case .playingVoice:
            return "話しています"
        case .recognizingSpeech:
            return "聞いています"
        case .processingResponse:
            return "処理中..."
        case .ended:
            return "通話終了"
        }
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .idle, .initializingVoiceVox, .requestingPermission:
            return .orange
        case .permissionGranted:
            return .green
        case .permissionDenied:
            return .red
        case .generatingScript, .synthesizingVoice, .processingResponse:
            return .blue
        case .playingVoice:
            return .purple
        case .recognizingSpeech:
            return .green
        case .ended:
            return .gray
        }
    }

    private var formattedDuration: String {
        let minutes = Int(viewModel.conversationDuration) / 60
        let seconds = Int(viewModel.conversationDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    CallView()
}
