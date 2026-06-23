import SwiftUI
import AVFoundation

/// AgentView の ViewModel。
/// 発話を `AgentRepository` に渡し、plan→端末ツール実行→返答 を受けて表示・音声再生する。
@MainActor
final class AgentViewModel: NSObject, ObservableObject {

    // MARK: - Published

    @Published var messages: [DisplayMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var isPlayingVoice = false
    @Published var expression: ZundamonExpression = .idle

    // MARK: - Types

    struct DisplayMessage: Identifiable {
        let id = UUID()
        let role: ChatMessage.Role
        let content: String
    }

    // MARK: - Private

    private let agentRepository: AgentRepository
    private let voicevoxRepository: TextToSpeechRepository
    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Init

    init(
        agentRepository: AgentRepository = AgentRepository(),
        voicevoxRepository: TextToSpeechRepository = VoicevoxRepository()
    ) {
        self.agentRepository = agentRepository
        self.voicevoxRepository = voicevoxRepository
        super.init()
    }

    // MARK: - Public

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        inputText = ""
        messages.append(DisplayMessage(role: .user, content: text))
        isLoading = true
        expression = .thinking

        Task {
            do {
                let result = try await agentRepository.run(message: text)
                let reply = result.reply.isEmpty ? "うまく答えられなかったのだ…" : result.reply
                let message = DisplayMessage(role: .assistant, content: reply)
                messages.append(message)
                // 返答の感情を表情に反映してから喋る
                expression = ZundamonExpression.from(emotion: result.emotion)
                await playVoice(text: reply)
            } catch {
                CrashlyticsManager.record(error)
                messages.append(DisplayMessage(
                    role: .assistant,
                    content: "ごめんなさいなのだ。エラーが発生してしまったのだ…"
                ))
            }
            isLoading = false
            expression = .idle
        }
    }

    func cleanup() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackContinuation?.resume()
        playbackContinuation = nil
        voicevoxRepository.cleanupSynthesizer()
        isPlayingVoice = false
        expression = .idle
    }

    // MARK: - Private

    private func playVoice(text: String) async {
        do {
            try await voicevoxRepository.installVoicevox()
            try voicevoxRepository.setupSynthesizer()

            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)

            let audioData = try await voicevoxRepository.synthesize(text: text)
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            // 合成完了後、実際の再生開始に合わせて口パクを始める。
            isPlayingVoice = true
            audioPlayer?.play()

            await withCheckedContinuation { continuation in
                playbackContinuation = continuation
            }

            voicevoxRepository.cleanupSynthesizer()
        } catch {
            print("音声再生エラー: \(error)")
            voicevoxRepository.cleanupSynthesizer()
        }
        isPlayingVoice = false
    }
}

// MARK: - AVAudioPlayerDelegate

extension AgentViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            playbackContinuation?.resume()
            playbackContinuation = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("音声デコードエラー: \(error?.localizedDescription ?? "不明なエラー")")
            playbackContinuation?.resume()
            playbackContinuation = nil
        }
    }
}
