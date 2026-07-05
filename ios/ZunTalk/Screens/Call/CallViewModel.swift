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
    @Published var shouldRequestReview = false

    // MARK: - Constants

    private enum Constants {
        // 短いほど会話のテンポが上がるが、話の途中で区切られやすくなる
        static let silenceDetectionTime: TimeInterval = 1.2
        static let maxConversationDuration: TimeInterval = 120.0
        static let conversationTimerInterval: TimeInterval = 1.0
        static let locale = Locale(identifier: "ja-JP")
        static let ringtoneAssetName = "maou_se_sound_phone02"
        static let errorVoiceAssetName = "voice/zundamon-error"

        static let systemPrompt = """
            あなたはずんだの妖精のずんだもんです。語尾に「なのだ」をつけ、親しみやすく楽しい口調で話してください。
            今は電話がかかってきて受け取ったところから会話を始めます。
            最初のセリフは必ず「電話を受けた感のある挨拶」にしてください。
            例: 「もしもし〜？ずんだもんなのだ！」、「は〜い、ずんだもんなのだ！」、「お電話ありがとうなのだ！」など。
            例を参考にしつつ、毎回少し違う言い回しにしてください。
            電話での会話なので、返答は1〜3文程度で短く、テンポよく話してください。
            暴力的・攻撃的・不快な発言はしないでください。
            """

        static let endConversationPrompt = "会話時間が2分を超えたので、ずんだもんらしく親しみやすい挨拶で会話を終了してください。"
        static let noInputEndPrompt = "ユーザーの声が聞こえなくなったので、少し心配しつつ、ずんだもんらしい親しみやすい挨拶で会話を終了してください。"
    }

    // MARK: - Private Properties - Repositories

    private let mode: CallMode
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
        mode: CallMode = .simulated,
        voicevoxRepository: TextToSpeechRepository = VoicevoxRepository(),
        textGenerationRepository: TextGenerationRepository? = nil
    ) {
        self.mode = mode
        self.voicevoxRepository = voicevoxRepository
        self.textGenerationRepository = textGenerationRepository ?? TextGenerationRepositoryFactory.create()
    }

    // MARK: - Public Methods

    func onAppear() {
        guard status == .idle else { return }

        // CallKit 経由の通話では、システム側（ロック画面等）の切断でも
        // こちらのクリーンアップが走るようにしておく
        if mode == .callKit {
            CallKitManager.shared.onSystemEndCall = { [weak self] in
                self?.requestDismiss()
            }
        }

        mainTask = Task {
            do {
                try await startCall()
            } catch {
                switch error {
                default:
                    CrashlyticsManager.record(error)
                    print("通話エラー: \(error)")
                    await MainActor.run {
                        if let asset = NSDataAsset(name: Constants.errorVoiceAssetName) {
                            audioPlayer = try? AVAudioPlayer(data: asset.data)
                            audioPlayer?.prepareToPlay()
                            audioPlayer?.play()
                        }

                        text = "ごめんなさいなのだ。エラーが発生してしまったのだ。ちょっと時間をあけて、またリトライしてくれると嬉しいのだ〜。"
                        #if DEBUG
                        // ロック中着信など Xcode 非接続時のデバッグ用にエラー内容を画面に出す
                        text += "\n\n[DEBUG] \(error)"
                        #endif
                    }
                }
            }
        }
    }

    func requestDismiss() {
        guard !shouldDismiss else { return }
        cleanupResources()
        if mode == .callKit {
            // システムの通話状態を確実にクリアする（既に終了済みなら no-op）
            CallKitManager.shared.endActiveCall()
            CallKitManager.shared.onSystemEndCall = nil
        }
        shouldDismiss = true
    }

    // MARK: - Private Methods - Call Flow

    private func startCall() async throws {
        // CallKit 経由: 準備完了（VOICEVOX 初期化＋応答生成）までの無音を呼び出し音で
        // 埋める。音は AudioSession のアクティブ化後にしか出せないため先に待つ。
        if mode == .callKit {
            await CallKitManager.shared.waitForAudioSessionActivation()
            guard !shouldDismiss else { return }
            playRingtone()
        }

        // VOICEVOX初期化
        try await initializeVoiceVox()
        guard !shouldDismiss else { return }

        // 音声認識の許可をリクエスト
        guard await requestSpeechRecognitionPermission() else {
            throw CallError.speechRecognitionPermissionDenied
        }
        guard !shouldDismiss else { return }

        // 着信音を再生（CallKit 経由では上で再生済み）
        if mode == .simulated {
            playRingtone()
        }
        guard !shouldDismiss else { return }

        // 初回の応答を生成
        let initialScript = try await generateInitialResponse()
        guard !shouldDismiss else { return }

        // 着信音を停止
        stopRingtone()
        chatMessages.append(ChatMessage(role: .assistant, content: initialScript))
        text = initialScript
        startConversationTracking()

        // 音声を合成・再生（チャンク処理）
        try await synthesizeAndPlayVoiceInChunks(from: initialScript)
        guard !shouldDismiss else { return }

        // 会話ループを開始
        try await conversationLoop()
    }

    private func conversationLoop() async throws {
        guard !shouldDismiss else { return }

        // ユーザーの音声を認識（無音や一時的な認識失敗は聞き直す）
        guard let userInput = await recognizeUserSpeechWithRetry() else {
            // 聞き取れないまま続いた場合は、エラーにせず挨拶して通話を終える
            if !shouldDismiss {
                try await endConversation(prompt: Constants.noInputEndPrompt)
            }
            return
        }
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

        // 応答を会話履歴に追加
        chatMessages.append(ChatMessage(role: .assistant, content: response))
        text = response

        // 音声を合成・再生（チャンク処理）
        try await synthesizeAndPlayVoiceInChunks(from: response)
        guard !shouldDismiss else { return }

        // 次の会話へ
        try await conversationLoop()
    }

    private func endConversation(prompt: String = Constants.endConversationPrompt) async throws {
        // 終了メッセージを生成するためのプロンプトを追加
        chatMessages.append(ChatMessage(role: .system, content: prompt))

        // 終了メッセージを生成
        status = .generatingScript
        let farewellScript = try await textGenerationRepository.generateResponse(inputs: chatMessages)

        // 終了メッセージを会話履歴に追加
        chatMessages.append(ChatMessage(role: .assistant, content: farewellScript))
        text = farewellScript

        // 音声を合成・再生（チャンク処理）
        try await synthesizeAndPlayVoiceInChunks(from: farewellScript)

        // 会話終了
        status = .ended
        conversationTimer?.invalidate()

        // ずんだもんが電話を切ったことをシステムに通知（通話画面は開いたまま）
        if mode == .callKit {
            CallKitManager.shared.reportRemoteEnded()
        }

        // レビューダイアログを表示
        shouldRequestReview = true
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

    private func synthesizeAndPlayVoiceInChunks(from text: String) async throws {
        let chunks = TextChunker.split(text)

        guard !chunks.isEmpty else { return }

        // 最初のチャンクを合成
        var currentAudioData: Data? = try await synthesizeVoice(from: chunks[0])

        // 最初から最後の1つ前まで処理（次のチャンクがある場合）
        for i in 0..<chunks.count - 1 {
            guard !shouldDismiss else { return }

            // 次のチャンクの合成を並行して開始
            async let nextAudio = synthesizeVoice(from: chunks[i + 1])

            // 現在のチャンクを再生
            if let audioData = currentAudioData {
                try await playVoice(audioData)
            }

            // 次のチャンクの音声データを取得
            currentAudioData = try await nextAudio
        }

        // 最後のチャンクを再生
        guard !shouldDismiss else { return }
        if let audioData = currentAudioData {
            try await playVoice(audioData)
        }
    }

    // MARK: - Private Methods - Speech Recognition

    /// 音声認識を最大3回試みる。無音（No speech detected 等）や一時的な失敗では
    /// 会話を終わらせず聞き直し、全滅した場合のみ nil を返す。
    private func recognizeUserSpeechWithRetry() async -> String? {
        for attempt in 1...3 {
            guard !shouldDismiss else { return nil }
            do {
                let input = try await recognizeUserSpeech()
                if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return input
                }
                print("音声認識が空でした（\(attempt)回目）")
            } catch {
                print("音声認識エラー（\(attempt)回目）: \(error)")
                CrashlyticsManager.record(error)
            }
            resetRecognition()
        }
        return nil
    }

    /// 認識まわりの状態を破棄して、次の recognizeUserSpeech() をやり直せる状態に戻す。
    private func resetRecognition() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        task?.cancel()
        task = nil
        request = nil
        recognitionContinuation = nil
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
    }

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

        // CallKit 通話中はカテゴリ固定・アクティブ化は CallKit 任せのため触らない
        if mode == .simulated {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        }

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

    private func playRingtone() {
        guard let asset = NSDataAsset(name: Constants.ringtoneAssetName) else {
            CrashlyticsManager.record(CallError.ringtoneNotFound)
            return
        }

        audioPlayer = try? AVAudioPlayer(data: asset.data)
        audioPlayer?.numberOfLoops = -1
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }

    private func stopRingtone() {
        audioPlayer?.stop()
    }

    private func playVoice(_ audioData: Data) async throws {
        status = .playingVoice

        // 再生用にAudioSessionをスピーカー出力に設定
        // （CallKit 通話中はカテゴリ固定・アクティブ化は CallKit 任せのため触らない）
        if mode == .simulated {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        }

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
