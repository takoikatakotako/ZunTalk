import SwiftUI
import Speech
import AVFoundation

@MainActor
class CallViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var text = ""
    @Published var status: CallStatus = .idle
    @Published var conversationDuration: TimeInterval = 0
    @Published var shouldDismiss = false

    // MARK: - Constants

    private enum Constants {
        static let silenceDetectionTime: TimeInterval = 2.0
        static let maxConversationDuration: TimeInterval = 120.0
        static let conversationTimerInterval: TimeInterval = 1.0
        static let locale = Locale(identifier: "ja-JP")
        static let ringtoneAssetName = "maou_se_sound_phone02"
        static let errorVoiceAssetName = "zundamon-error"

        static let systemPrompt = """
            あなたはずんだの妖精のずんだもんです。語尾に「なのだ」をつけ、親しみやすく楽しい口調で話してください。
            今は電話がかかってきて受け取ったところから会話を始めます。
            最初のセリフは必ず「電話を受けた感のある挨拶」にしてください。
            例: 「もしもし〜？ずんだもんなのだ！」、「は〜い、ずんだもんなのだ！」、「お電話ありがとうなのだ！」など。
            例を参考にしつつ、毎回少し違う言い回しにしてください。
            暴力的・攻撃的・不快な発言はしないでください。
            """

        static let endConversationPrompt = "会話時間が1分を超えたので、ずんだもんらしく親しみやすい挨拶で会話を終了してください。"
    }

    // MARK: - Private Properties - Repositories

    private let voicevoxRepository: TextToSpeechRepository
    private let textGenerationRepository: TextGenerationRepository

    // MARK: - Private Properties - Speech Recognition

    private let recognizer = SFSpeechRecognizer(locale: Constants.locale)
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognitionContinuation: CheckedContinuation<String, Error>?

    // MARK: - Private Properties - Audio Playback

    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Bool, Never>?

    // MARK: - Private Properties - Timers

    private var silenceTimer: Timer?
    private var conversationTimer: Timer?
    private var speechRecognitionStartTime: Date?

    // MARK: - Private Properties - State

    private var chatMessages: [ChatMessage] = []
    private var mainTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        voicevoxRepository: TextToSpeechRepository = VoicevoxRepository(),
        textGenerationRepository: TextGenerationRepository = OpenAITextGenerationRepository()
    ) {
        self.voicevoxRepository = voicevoxRepository
        self.textGenerationRepository = textGenerationRepository
    }

    // MARK: - Public Methods

    func onAppear() {
        guard status == .idle else { return }

        mainTask = Task {
            do {
                try await startCall()
            } catch {
                switch error {
                default:
                    print("通話エラー: \(error)")
                    await MainActor.run {
                        if let asset = NSDataAsset(name: Constants.errorVoiceAssetName) {
                            audioPlayer = try? AVAudioPlayer(data: asset.data)
                            audioPlayer?.prepareToPlay()
                            audioPlayer?.play()
                        }

                        text = "ごめんなさいなのだ。エラーが発生してしまったのだ。ちょっと時間をあけて、またリトライしてくれると嬉しいのだ〜。"
                    }
                }
            }
        }
    }

    func requestDismiss() {
        cleanupResources()
        shouldDismiss = true
    }

    // MARK: - Private Methods - Call Flow

    private func startCall() async throws {
        // VOICEVOX初期化
        try await initializeVoiceVox()
        guard !shouldDismiss else { return }

        // 音声認識の許可をリクエスト
        guard await requestSpeechRecognitionPermission() else {
            throw CallError.speechRecognitionPermissionDenied
        }
        guard !shouldDismiss else { return }

        // 着信音を再生
        try playRingtone()
        guard !shouldDismiss else { return }

        // 初回の応答を生成
        let initialScript = try await generateInitialResponse()
        guard !shouldDismiss else { return }

        // 音声を合成
        let initialVoice = try await synthesizeVoice(from: initialScript)
        guard !shouldDismiss else { return }

        // 着信音を停止
        stopRingtone()
        text = initialScript
        startConversationTracking()

        // 音声を再生
        try await playVoice(initialVoice)
        guard !shouldDismiss else { return }

        // 会話ループを開始
        try await conversationLoop()
    }

    private func conversationLoop() async throws {
        guard !shouldDismiss else { return }

        // ユーザーの音声を認識
        let userInput = try await recognizeUserSpeech()
        guard !shouldDismiss else { return }

        // 会話時間を確認
        if shouldEndConversation() {
            try await endConversation()
            return
        }

        // ユーザーの発言を会話履歴に追加
        chatMessages.append(ChatMessage(role: .user, content: userInput))

        // 応答を生成
        let response = try await generateResponse()
        guard !shouldDismiss else { return }

        // 音声を合成
        let voice = try await synthesizeVoice(from: response)
        guard !shouldDismiss else { return }

        // 応答を会話履歴に追加
        chatMessages.append(ChatMessage(role: .assistant, content: response))
        text = response

        // 音声を再生
        try await playVoice(voice)
        guard !shouldDismiss else { return }

        // 次の会話へ
        try await conversationLoop()
    }

    private func endConversation() async throws {
        // 終了メッセージを生成するためのプロンプトを追加
        chatMessages.append(ChatMessage(role: .system, content: Constants.endConversationPrompt))

        // 終了メッセージを生成
        status = .generatingScript
        let farewellScript = try await textGenerationRepository.generateResponse(inputs: chatMessages)

        // 音声を合成
        let farewellVoice = try await synthesizeVoice(from: farewellScript)

        // 終了メッセージを会話履歴に追加
        chatMessages.append(ChatMessage(role: .assistant, content: farewellScript))
        text = farewellScript

        // 音声を再生
        try await playVoice(farewellVoice)

        // 会話終了
        status = .ended
        conversationTimer?.invalidate()
    }

    // MARK: - Private Methods - VOICEVOX

    private func initializeVoiceVox() async throws {
        status = .initializingVoiceVox
        try await voicevoxRepository.installVoicevox()
        try voicevoxRepository.setupSynthesizer()
    }

    private func synthesizeVoice(from script: String) async throws -> Data {
        status = .synthesizingVoice
        return try await voicevoxRepository.synthesize(text: script)
    }

    // MARK: - Private Methods - Speech Recognition

    private func requestSpeechRecognitionPermission() async -> Bool {
        status = .requestingPermission

        let authStatus = SFSpeechRecognizer.authorizationStatus()

        switch authStatus {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default:
            return false
        }
    }

    private func recognizeUserSpeech() async throws -> String {
        status = .recognizingSpeech
        text = ""

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .mixWithOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        task = recognizer?.recognitionTask(with: request!) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                print("音声認識エラー: \(error.localizedDescription)")
                Task { @MainActor in
                    self.recognitionContinuation?.resume(throwing: CallError.speechRecognitionFailed(error))
                    self.recognitionContinuation = nil
                }
                return
            }

            guard let result = result, !result.isFinal else { return }

            let recognizedText = result.bestTranscription.formattedString

            DispatchQueue.main.async {
                self.text = recognizedText
            }

            self.silenceTimer?.invalidate()
            self.silenceTimer = Timer.scheduledTimer(
                withTimeInterval: Constants.silenceDetectionTime,
                repeats: false
            ) { _ in
                Task { @MainActor in
                    self.stopRecognition()
                }
            }
        }

        try engine.start()

        return try await withCheckedThrowingContinuation { continuation in
            recognitionContinuation = continuation
        }
    }

    private func stopRecognition() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()

        recognitionContinuation?.resume(returning: text)
        recognitionContinuation = nil
    }

    // MARK: - Private Methods - Text Generation

    private func generateInitialResponse() async throws -> String {
        status = .generatingScript
        chatMessages.append(ChatMessage(role: .system, content: Constants.systemPrompt))
        return try await textGenerationRepository.generateResponse(inputs: chatMessages)
    }

    private func generateResponse() async throws -> String {
        status = .generatingScript
        return try await textGenerationRepository.generateResponse(inputs: chatMessages)
    }

    // MARK: - Private Methods - Audio Playback

    private func playRingtone() throws {
        guard let asset = NSDataAsset(name: Constants.ringtoneAssetName) else {
            throw CallError.ringtoneNotFound
        }

        audioPlayer = try AVAudioPlayer(data: asset.data)
        audioPlayer?.numberOfLoops = -1
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }

    private func stopRingtone() {
        audioPlayer?.stop()
    }

    private func playVoice(_ audioData: Data) async throws {
        status = .playingVoice

        audioPlayer = try AVAudioPlayer(data: audioData)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()

        let success = await withCheckedContinuation { continuation in
            playbackContinuation = continuation
        }

        if !success {
            throw CallError.audioPlaybackFailed
        }
    }

    // MARK: - Private Methods - Conversation Tracking

    private func startConversationTracking() {
        speechRecognitionStartTime = Date()
        startConversationTimer()
    }

    private func startConversationTimer() {
        conversationTimer?.invalidate()
        conversationTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.conversationTimerInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let startTime = self.speechRecognitionStartTime else { return }
                self.conversationDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func shouldEndConversation() -> Bool {
        guard let startTime = speechRecognitionStartTime else { return false }
        return Date().timeIntervalSince(startTime) >= Constants.maxConversationDuration
    }

    // MARK: - Private Methods - Cleanup

    private func cleanupResources() {
        mainTask?.cancel()
        mainTask = nil

        silenceTimer?.invalidate()
        silenceTimer = nil
        conversationTimer?.invalidate()
        conversationTimer = nil

        task?.cancel()
        task?.finish()
        task = nil
        request?.endAudio()
        request = nil

        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }

        audioPlayer?.stop()
        audioPlayer = nil

        chatMessages.removeAll()
        voicevoxRepository.cleanupSynthesizer()
    }
}

// MARK: - AVAudioPlayerDelegate

extension CallViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            playbackContinuation?.resume(returning: flag)
            playbackContinuation = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("音声デコードエラー: \(error?.localizedDescription ?? "不明なエラー")")
            playbackContinuation?.resume(returning: false)
            playbackContinuation = nil
        }
    }
}
