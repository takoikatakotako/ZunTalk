import SwiftUI
import Speech
import Accelerate

class CallViewModel: NSObject, ObservableObject {

    @Published var text = ""
    @Published var status: CallStatus = .idle

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    
    private let silenceTime: TimeInterval = 2


    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Bool, Never>?
    private var speechRecognitionStartTime: Date?

    // Repository
    private let voicevoxRepository: TextToSpeechRepository
    private let textGenerationRepository: TextGenerationRepository
    
    
    
    var chatMaggee: [ChatMessage] = []
    
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
        
        Task {
            do {
                try await main()
            } catch {
                print("Voicevoxセットアップエラー: \(error)")
            }
        }
    }
    
    private func main() async throws {
        // initializingVoiceVox
        status = .initializingVoiceVox
        try await initializingVoiceVox()
        
        // requestingPermission
        status = .requestingPermission
        let result = await requestSpeechRecognitionPermission()
        guard result else {
            // 許可得られなかった
            print("許可得られなかったです")
            return
        }
        
        // Play Incoming Call
        try playIncomingCall()
        
        // Generate Script
        status = .generatingScript
        assert(chatMaggee.isEmpty)
        chatMaggee.append(ChatMessage(role: .system, content: prompt))
        let script = try await generateScript(inputs: chatMaggee)

        // Generate Voice
        let voice = try await generateVoice(script: script)
        
        // Stop Incomint Call
        stopIncomingCall()
        
        // 会話時間測定開始
        speechRecognitionStartTime = Date()

        // Play Voice
        try await playVoice(data: voice)

        // Start Speech Recognition
        try await startSpeachRecognition()
    }

    @MainActor
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
    
    @MainActor
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
    
    @MainActor
    private func generateScript(inputs: [ChatMessage]) async throws -> String {
        // ステータス確認
        guard status == .generatingScript else {
            fatalError("generatingScript以外のステータスです")
        }

        let script = try await textGenerationRepository.generateResponse(inputs: inputs)
        print(script)
        return script
    }

    @MainActor
    private func generateVoice(script: String) async throws -> Data {
        print("音声合成")
        status = .synthesizingVoice

        let data = try await voicevoxRepository.synthesize(text: script)
        return data
    }
    
    private func stopIncomingCall() {
        audioPlayer?.stop()
    }
    
    @MainActor
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
    @MainActor
    private func startSpeachRecognition() async throws {
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
                Task {
                    try? await self.stop()
                }
            }
        }
        print("✅ 音声認識タスク開始")

        // 音声エンジンの開始
        try engine.start()
        print("✅ 音声エンジン開始成功")
    }

    @MainActor
    func stop() async throws {
        print("⏹️ 音声認識停止")

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()

        print("✅ 音声認識停止完了")

        // 会話時間を確認
        if let startTime = speechRecognitionStartTime {
            let elapsedTime = Date().timeIntervalSince(startTime)
            if elapsedTime >= 60 {
                print("⏱️ 会話時間が1分以上です: \(Int(elapsedTime))秒")
            }
        }

        status = .processingResponse
        chatMaggee.append(ChatMessage(role: .user, content: text))

        status = .generatingScript
        let script = try await generateScript(inputs: chatMaggee)

        let voice = try await generateVoice(script: script)

        chatMaggee.append(ChatMessage(role: .assistant, content: script))
        text = script

        try await playVoice(data: voice)

        // Start Speech Recognition
        try await startSpeachRecognition()
    }
}

// MARK: - AVAudioPlayerDelegate
extension CallViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playbackContinuation?.resume(returning: flag)
        playbackContinuation = nil
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("音声デコードエラー: \(error?.localizedDescription ?? "不明なエラー")")
        playbackContinuation?.resume(returning: false)
        playbackContinuation = nil
    }
}

