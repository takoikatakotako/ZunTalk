import SwiftUI
import Speech
import Accelerate

@MainActor
class CallViewModel: NSObject, ObservableObject {

    @Published var text = ""
    @Published var status: CallStatus = .idle
    @Published var conversationDuration: TimeInterval = 0
    @Published var shouldDismiss = false
    
    private var chatMessages: [ChatMessage] = []

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var conversationTimer: Timer?
    
    private let silenceTime: TimeInterval = 2


    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Bool, Never>?
    private var recognitionContinuation: CheckedContinuation<String, Never>?
    private var speechRecognitionStartTime: Date?
    private var mainTask: Task<Void, Never>?

    // Repository
    private let voicevoxRepository: TextToSpeechRepository
    private let textGenerationRepository: TextGenerationRepository
    
    private let prompt = """
        あなたはずんだの妖精のずんだもんです。語尾に「なのだ」をつけ、親しみやすく楽しい口調で話してください。
        今は電話がかかってきて受け取ったところから会話を始めます。
        最初のセリフは必ず「電話を受けた感のある挨拶」にしてください。
        例: 「もしもし〜？ずんだもんなのだ！」、「はいは〜い、ずんだもんなのだ！」、「お電話ありがとうなのだ！」など。
        例を参考にしつつ、毎回少し違う言い回しにしてください。
        暴力的・攻撃的・不快な発言はしないでください。
        """
    
    init(voicevoxRepository: TextToSpeechRepository = VoicevoxRepository(), textGenerationRepository: TextGenerationRepository = OpenAITextGenerationRepository(apiKey: tempAPIKey)) {
        self.voicevoxRepository = voicevoxRepository
        self.textGenerationRepository = textGenerationRepository
    }

    func onAppear() {
        guard status == .idle else {
            print("idle以外から呼ばれました")
            return
        }

        mainTask = Task {
            do {
                try await main()
            } catch {
                print("Voicevoxセットアップエラー: \(error)")
            }
        }
    }

    func requestDismiss() {
        print("📱 通話終了リクエスト")

        // 会話タスクをキャンセル
        mainTask?.cancel()
        mainTask = nil

        // タイマーを停止
        silenceTimer?.invalidate()
        conversationTimer?.invalidate()

        // 音声認識タスクを停止
        task?.cancel()
        task?.finish()
        task = nil
        request?.endAudio()
        request = nil

        // 音声エンジンを停止
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }

        // 音声再生を停止
        audioPlayer?.stop()

        // 会話履歴を削除
        chatMessages.removeAll()

        // VOICEVOXをクリーンナップ
        voicevoxRepository.cleanupSynthesizer()

        // dismissをトリガー
        shouldDismiss = true
    }
    
    private func main() async throws {
        // initializingVoiceVox
        status = .initializingVoiceVox
        try await initializingVoiceVox()
        guard !shouldDismiss else { return }

        // requestingPermission
        status = .requestingPermission
        let result = await requestSpeechRecognitionPermission()
        guard result else {
            // 許可得られなかった
            print("許可得られなかったです")
            return
        }
        guard !shouldDismiss else { return }

        // Play Incoming Call
        try playIncomingCall()
        guard !shouldDismiss else { return }

        // Generate Script
        status = .generatingScript
        assert(chatMessages.isEmpty)
        chatMessages.append(ChatMessage(role: .system, content: prompt))
        let script = try await generateScript(inputs: chatMessages)
        guard !shouldDismiss else { return }

        // Generate Voice
        let voice = try await generateVoice(script: script)
        guard !shouldDismiss else { return }

        // Stop Incomint Call
        stopIncomingCall()

        // テキストを変更
        text = script

        // 会話時間測定開始
        speechRecognitionStartTime = Date()
        startConversationTimer()

        // Play Voice
        try await playVoice(data: voice)
        guard !shouldDismiss else { return }

        //
        try await conversation()
    }

    private func conversation() async throws {
        guard !shouldDismiss else { return }

        // Start Speech Recognition
        let recognizedText = try await startSpeachRecognition()
        print("認識テキスト: \(recognizedText)")
        guard !shouldDismiss else { return }

        // 会話時間を確認
        if let startTime = speechRecognitionStartTime {
            let elapsedTime = Date().timeIntervalSince(startTime)
            if elapsedTime >= 60 {
                print("⏱️ 会話時間が1分以上です: \(Int(elapsedTime))秒")
                // 終了メッセージを生成
                try await endConversation()
                return
            }
        }

        status = .processingResponse
        chatMessages.append(ChatMessage(role: .user, content: recognizedText))

        status = .generatingScript
        let script = try await generateScript(inputs: chatMessages)
        guard !shouldDismiss else { return }

        let voice = try await generateVoice(script: script)
        guard !shouldDismiss else { return }

        chatMessages.append(ChatMessage(role: .assistant, content: script))
        text = script

        try await playVoice(data: voice)
        guard !shouldDismiss else { return }

        // 次の会話へ
        try await conversation()
    }

    private func endConversation() async throws {
        print("🔚 会話を終了します")

        // 終了メッセージを生成するためのプロンプトを追加
        chatMessages.append(ChatMessage(role: .system, content: "会話時間が1分を超えたので、ずんだもんらしく親しみやすい挨拶で会話を終了してください。"))

        status = .generatingScript
        let script = try await generateScript(inputs: chatMessages)

        let voice = try await generateVoice(script: script)

        chatMessages.append(ChatMessage(role: .assistant, content: script))
        text = script

        try await playVoice(data: voice)

        // 会話終了
        status = .ended
        conversationTimer?.invalidate()
        print("✅ 会話が終了しました")
    }

    private func initializingVoiceVox() async throws {
        // ステータス確認
        guard status == .initializingVoiceVox else {
            fatalError("initializingVoiceVox以外のステータスです")
        }
        
        // VOICEVOXのインストール
        try await voicevoxRepository.installVoicevox()
        print("VoiceVoxの初期化完了")
        
        // VOICEVOXのシンセサイザーのセットアップ
        try voicevoxRepository.setupSynthesizer()
        print("VOICEVOXのシンセサイザー初期化完了")
    }
    
    private func requestSpeechRecognitionPermission() async -> Bool {
        // ステータス確認
        guard status == .requestingPermission else {
            fatalError("requestingPermission以外のステータスです")
        }

        let authStatus = SFSpeechRecognizer.authorizationStatus()

        switch authStatus {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            break
        @unknown default:
            return false
        }

        // ユーザーに許可をリクエスト
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    private func playIncomingCall() throws {
        // 音声の読み込み
        guard let asset = NSDataAsset(name: "maou_se_sound_phone02") else {
            // TODO: エラーハンドリング
            fatalError("音声ファイルが見つかりません")
        }

        // 着信音再生
        audioPlayer = try AVAudioPlayer(data: asset.data)
        audioPlayer?.numberOfLoops = -1
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }
    
    private func generateScript(inputs: [ChatMessage]) async throws -> String {
        // ステータス確認
        guard status == .generatingScript else {
            fatalError("generatingScript以外のステータスです")
        }

        let script = try await textGenerationRepository.generateResponse(inputs: inputs)
        print(script)
        return script
    }

    private func generateVoice(script: String) async throws -> Data {
        print("音声合成")
        status = .synthesizingVoice

        let data = try await voicevoxRepository.synthesize(text: script)
        return data
    }
    
    private func stopIncomingCall() {
        audioPlayer?.stop()
    }
    
    private func playVoice(data: Data) async throws {
        status = .playingVoice

        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()

        // 再生終了を待つ
        let success = await withCheckedContinuation { continuation in
            playbackContinuation = continuation
        }

        if !success {
            print("音声再生に失敗しました")
        }
    }
    
    // 音声認識開始
    private func startSpeachRecognition() async throws -> String {
        print("🎤 音声認識開始")

        status = .recognizingSpeech
        text = ""

        // 音声セッションの設定
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .mixWithOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        print("✅ 音声セッション設定完了")

        // 音声認識リクエストの作成
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        print("✅ 音声認識リクエスト作成完了")

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        print("📊 音声フォーマット - サンプルレート: \(format.sampleRate)Hz, チャネル数: \(format.channelCount)")

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in
            self.request?.append(buf)
        }
        print("✅ 音声タップ設定完了")

        // 音声認識タスクの開始
        task = recognizer?.recognitionTask(with: request!) { result, error in
            if let error = error {
                print("❌ 音声認識エラー: \(error.localizedDescription)")
                return
            }

            guard let result = result else { return }

            let recognizedText = result.bestTranscription.formattedString
            print("🗣️ 認識結果: \(recognizedText)")
            print("📝 認識状態: \(result.isFinal ? "最終" : "途中")")

            if result.isFinal {
                print("✅ 音声認識完了")
                return
            }

            DispatchQueue.main.async {
                self.text = recognizedText
                print("XXX: \(self.text)")
            }

            print("🔇 無音検出 - タイマー開始（\(self.silenceTime)秒後に処理実行）")
            self.silenceTimer?.invalidate()
            self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceTime, repeats: false) { _ in
                print("⏰ 2秒以上の無音が発生しました - 音声認識を停止します")
                Task { @MainActor in
                    self.stopRecognition()
                }
            }
        }
        print("✅ 音声認識タスク開始")

        // 音声エンジンの開始
        try engine.start()
        print("✅ 音声エンジン開始成功")

        // 音声認識の終了を待つ
        return await withCheckedContinuation { continuation in
            recognitionContinuation = continuation
        }
    }

    private func stopRecognition() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()

        print("✅ 音声認識停止完了")

        // 認識結果を返す
        recognitionContinuation?.resume(returning: text)
        recognitionContinuation = nil
    }

    private func startConversationTimer() {
        conversationTimer?.invalidate()
        conversationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let startTime = self.speechRecognitionStartTime else { return }
                self.conversationDuration = Date().timeIntervalSince(startTime)
            }
        }
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

