import SwiftUI
import AVFoundation

@MainActor
class ChatViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var messages: [DisplayMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var isPlayingVoice = false
    @Published var playingMessageId: UUID?
    @Published var isConversationEnded = false

    // MARK: - Types

    struct DisplayMessage: Identifiable {
        let id = UUID()
        let role: ChatMessage.Role
        let content: String
    }

    // MARK: - Constants

    private enum Constants {
        static let systemPrompt = """
            あなたはずんだの妖精のずんだもんです。語尾に「なのだ」をつけ、親しみやすく楽しい口調で話してください。
            暴力的・攻撃的・不快な発言はしないでください。
            チャットでの会話なので、短めに返答してください。
            """
        static let maxRoundTrips = 40
        static let endConversationPrompt = "会話回数の上限に達したので、ずんだもんらしく親しみやすい挨拶で会話を終了してください。"
    }

    // MARK: - Private Properties

    private let textGenerationRepository: TextGenerationRepository
    private let voicevoxRepository: TextToSpeechRepository
    private var chatMessages: [ChatMessage] = []
    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Initialization

    init(
        textGenerationRepository: TextGenerationRepository? = nil,
        voicevoxRepository: TextToSpeechRepository = VoicevoxRepository()
    ) {
        self.textGenerationRepository = textGenerationRepository ?? TextGenerationRepositoryFactory.create()
        self.voicevoxRepository = voicevoxRepository
        super.init()
        chatMessages.append(ChatMessage(role: .system, content: Constants.systemPrompt))
    }

    // MARK: - Public Methods

    func onAppear() {
        guard messages.isEmpty else { return }
        AnalyticsManager.logChatStarted()
        generateInitialGreeting()
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading, !isConversationEnded else { return }

        inputText = ""
        messages.append(DisplayMessage(role: .user, content: text))
        chatMessages.append(ChatMessage(role: .user, content: text))

        let userMessageCount = messages.filter { $0.role == .user }.count
        AnalyticsManager.logMessageSent(messageCount: userMessageCount)

        isLoading = true

        Task {
            do {
                if userMessageCount >= Constants.maxRoundTrips {
                    chatMessages.append(ChatMessage(role: .system, content: Constants.endConversationPrompt))
                }

                let response = try await textGenerationRepository.generateResponse(inputs: chatMessages)
                chatMessages.append(ChatMessage(role: .assistant, content: response))
                let message = DisplayMessage(role: .assistant, content: response)
                messages.append(message)
                await playVoice(text: response, messageId: message.id)

                if userMessageCount >= Constants.maxRoundTrips {
                    isConversationEnded = true
                }
            } catch {
                messages.append(DisplayMessage(role: .assistant, content: "ごめんなさいなのだ。エラーが発生してしまったのだ…"))
            }
            isLoading = false
        }
    }

    func replayVoice(for message: DisplayMessage) {
        guard playingMessageId == nil, !isLoading else { return }

        Task {
            await playVoice(text: message.content, messageId: message.id)
        }
    }

    func cleanup() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackContinuation?.resume()
        playbackContinuation = nil
        voicevoxRepository.cleanupSynthesizer()
        playingMessageId = nil
        isPlayingVoice = false
    }

    // MARK: - Private Methods

    private func generateInitialGreeting() {
        isLoading = true

        Task {
            do {
                let response = try await textGenerationRepository.generateResponse(inputs: chatMessages)
                chatMessages.append(ChatMessage(role: .assistant, content: response))
                let message = DisplayMessage(role: .assistant, content: response)
                messages.append(message)
                await playVoice(text: response, messageId: message.id)
            } catch {
                messages.append(DisplayMessage(role: .assistant, content: "エラーが出てしまったのだ…時間をあけてもう一度試して欲しいのだ！"))
                isConversationEnded = true
            }
            isLoading = false
        }
    }

    private func playVoice(text: String, messageId: UUID) async {
        do {
            playingMessageId = messageId
            isPlayingVoice = true

            try await voicevoxRepository.installVoicevox()
            try voicevoxRepository.setupSynthesizer()

            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)

            let audioData = try await voicevoxRepository.synthesize(text: text)
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            await withCheckedContinuation { continuation in
                playbackContinuation = continuation
            }

            voicevoxRepository.cleanupSynthesizer()
        } catch {
            print("音声再生エラー: \(error)")
            voicevoxRepository.cleanupSynthesizer()
        }
        playingMessageId = nil
        isPlayingVoice = false
    }
}

// MARK: - AVAudioPlayerDelegate

extension ChatViewModel: AVAudioPlayerDelegate {
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
