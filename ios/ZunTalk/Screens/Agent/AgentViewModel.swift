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
    private var hasPlayedInitialGreeting = false

    private enum Constants {
        static let fallbackInitialGreeting = "こんばんは。今日は何を話すのだ？"
    }

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

    func playInitialGreetingIfNeeded() {
        guard !hasPlayedInitialGreeting, messages.isEmpty, !isLoading, !isPlayingVoice else { return }
        hasPlayedInitialGreeting = true
        isLoading = true
        expression = .thinking

        Task {
            let greeting: String
            do {
                let result = try await agentRepository.run(message: initialGreetingPrompt())
                greeting = result.reply.isEmpty ? Constants.fallbackInitialGreeting : result.reply
                expression = ZundamonExpression.from(emotion: result.emotion)
            } catch AgentError.rateLimited(let message) {
                greeting = message
                expression = .idle
            } catch {
                CrashlyticsManager.record(error)
                greeting = Constants.fallbackInitialGreeting
                expression = .idle
            }

            await presentAndPlayAssistantMessage(greeting)
            expression = .idle
        }
    }

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
                // 返答の感情を表情に反映してから喋る
                expression = ZundamonExpression.from(emotion: result.emotion)
                await presentAndPlayAssistantMessage(reply)
            } catch AgentError.rateLimited(let message) {
                // 日次利用回数の上限。エラー扱いにせず、ずんだもんの言葉として届ける
                expression = ZundamonExpression.from(emotion: "troubled")
                await presentAndPlayAssistantMessage(message)
            } catch {
                CrashlyticsManager.record(error)
                isLoading = false
                messages.append(DisplayMessage(
                    role: .assistant,
                    content: "ごめんなさいなのだ。エラーが発生してしまったのだ…"
                ))
            }
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

    private func initialGreetingPrompt() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy年M月d日(E) HH:mm"
        let now = formatter.string(from: Date())

        return """
        現在日時は \(now) です。
        端末ツールは使わず、現在の時間帯に合う自然な一言の挨拶を作ってください。
        あなたはずんだもんです。親しみやすく、短めに、語尾は必要に応じて「なのだ」を使ってください。
        ユーザーに今日何を話したいか軽く問いかけてください。
        """
    }

    private func presentAndPlayAssistantMessage(_ text: String) async {
        var didPresent = false
        let didStartPlayback = await playVoice(text: text) {
            didPresent = true
            self.isLoading = false
            self.messages.append(DisplayMessage(role: .assistant, content: text))
        }

        if !didStartPlayback && !didPresent {
            isLoading = false
            messages.append(DisplayMessage(role: .assistant, content: text))
        }
    }

    private func playVoice(text: String, onReadyToPlay: (() -> Void)? = nil) async -> Bool {
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
            onReadyToPlay?()
            // 合成完了後、実際の再生開始に合わせて口パクを始める。
            isPlayingVoice = true
            audioPlayer?.play()

            await withCheckedContinuation { continuation in
                playbackContinuation = continuation
            }

            voicevoxRepository.cleanupSynthesizer()
            isPlayingVoice = false
            return true
        } catch {
            print("音声再生エラー: \(error)")
            voicevoxRepository.cleanupSynthesizer()
            isPlayingVoice = false
            return false
        }
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
