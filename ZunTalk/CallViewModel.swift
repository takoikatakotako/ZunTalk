import SwiftUI
import Speech
import Accelerate

class CallViewModel: NSObject, ObservableObject {
    
    @Published var text = ""
    @Published var isRecording = false
    
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    
    private let silenceThreshold: Float = 0.01
    private let silenceTime: TimeInterval = 2.0
    
    
    private var audioPlayer: AVAudioPlayer?
    
    // Repository
    private let voicevoxRepository: TextToSpeechRepository
    private let textGenerationRepository: TextGenerationRepository
    
    init(voicevoxRepository: TextToSpeechRepository = VoicevoxRepository(), textGenerationRepository: TextGenerationRepository = OpenAITextGenerationRepository(apiKey: tempAPIKey)) {
        self.voicevoxRepository = voicevoxRepository
        self.textGenerationRepository = textGenerationRepository
    }
    
    // OpenAI LLM統合用の初期化メソッド
    convenience init(openAIAPIKey: String) {
        let textGenRepo = OpenAITextGenerationRepository(apiKey: openAIAPIKey)
        self.init(voicevoxRepository: VoicevoxRepository(), textGenerationRepository: textGenRepo)
    }
    
    
    //
    //    var speechRecognizer:SFSpeechRecognizer?
    ////    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    //    var recognitionTask: SFSpeechRecognitionTask?
    //
    
    func onAppear() {
        Task {
            do {
                // 音声の読み込み
                guard let asset = NSDataAsset(name: "maou_se_sound_phone02") else {
                    // TODO: エラーハンドリング
                    print("音声ファイルが見つかりません")
                    return
                }
                
                // 着信音再生
                audioPlayer = try AVAudioPlayer(data: asset.data)
                audioPlayer?.numberOfLoops = -1 
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                
                // Voicevoxの初期化
                try await voicevoxRepository.installVoicevox()
                print("Voicevoxセットアップ完了")
                try voicevoxRepository.setupSynthesizer()
                
                // main
                try await main()
            } catch {
                print("Voicevoxセットアップエラー: \(error)")
            }
        }
    }
    
    private func main() async throws {
        let script = try await generateScript()
        let voice = try await generateVoice(script: script)
        Task { @MainActor in
            self.text = script
        }
        try playVoice(data: voice)
    }
    
    
    // スクリプト生成
    func generateScript() async throws -> String {
        print("スクリプト生成")
        let script = try await textGenerationRepository.generateResponse(userMessage: "")
        print(script)
        return script
    }

    // 音声合成
    func generateVoice(script: String) async throws -> Data {
        print("音声合成")
        let data = try await voicevoxRepository.synthesize(text: script)
        return data
    }
    
    // 音声再生
    func playVoice(data: Data) throws {
        print("音声再生")
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }
    
    // 音声認識開始
    func startSpeachRecognition() {
        print("🎤 音声認識開始")
        
        // 音声セッションの設定
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ 音声セッション設定完了")
        } catch {
            print("❌ 音声セッション設定エラー: \(error)")
            return
        }
        
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
//            self.detectSilence(buf)
        }
        print("✅ 音声タップ設定完了")
        
        // 音声認識タスクの開始
        task = recognizer?.recognitionTask(with: request!) { result, error in
            if let error = error {
                print("❌ 音声認識エラー: \(error.localizedDescription)")
                return
            }
            
            if let result = result {
                let recognizedText = result.bestTranscription.formattedString
                print("🗣️ 認識結果: \(recognizedText)")
                print("📝 認識状態: \(result.isFinal ? "最終" : "途中")")
                
                DispatchQueue.main.async { 
                    self.text = recognizedText
                }
                
//                if result.isFinal {
//                    print("✅ 音声認識完了")
//                    self.stop()
//                }
                
                
                print("🔇 無音検出 - タイマー開始（\(self.silenceTime)秒後に処理実行）")
                self.silenceTimer?.invalidate()
                self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceTime, repeats: false) { _ in
                    print("⏰ 2秒以上の無音が発生しました - 音声認識を停止します")
                    self.stop()
                }
            }
        }
        print("✅ 音声認識タスク開始")
        
        // 音声エンジンの開始
        do {
            try engine.start()
            print("✅ 音声エンジン開始成功")
            isRecording = true
        } catch {
            print("❌ 音声エンジン開始エラー: \(error)")
        }
    }
    
//    /// 音声バッファから無音を検出し、一定時間無音が続いたら処理を実行する
//    /// - Parameter buffer: 音声データを含むPCMバッファ
//    /// 
//    /// 動作:
//    /// 1. RMS（Root Mean Square）を計算して音声の振幅レベルを測定
//    /// 2. silenceThreshold (0.01) 未満なら無音と判定
//    /// 3. 無音が silenceTime (2.0秒) 続いたら処理実行
//    /// 4. 音声が検出されたらタイマーをリセット
//    private func detectSilence(_ buffer: AVAudioPCMBuffer) {
//        return
//        guard let data = buffer.floatChannelData?[0] else {
//            print("⚠️ 音声データの取得に失敗")
//            return 
//        }
//        
//        // RMS (Root Mean Square) 計算: 音声の振幅レベルを0.0〜1.0で表現
//        let rms = sqrt(stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
//            .map { data[$0] * data[$0] }.reduce(0,+) / Float(buffer.frameLength))
//        
//        // 音声レベルをログ出力（デバッグ用、必要に応じてコメントアウト）
//        // print("🔊 音声レベル: \(String(format: "%.4f", rms)) (閾値: \(silenceThreshold))")
//        
//        if rms < silenceThreshold {
//            // 無音検出: silenceTime秒後に処理実行
//            print("🔇 無音検出 - タイマー開始（\(silenceTime)秒後に処理実行）")
//            silenceTimer?.invalidate()
//            silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTime, repeats: false) { _ in
//                print("⏰ 2秒以上の無音が発生しました - 音声認識を停止します")
//                self.stop()
//            }
//        } else {
//            // 音声検出: タイマーをリセット
//            if silenceTimer != nil {
//                print("🎤 音声検出 - 無音タイマーをリセット")
//            }
//            silenceTimer?.invalidate()
//        }
//    }
    
    func stop() {
        print("⏹️ 音声認識停止")
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        isRecording = false
        silenceTimer?.invalidate()
        print("✅ 音声認識停止完了")
    }
    
    
    // 音声合成メソッド
    private func synthesizeSpeech(text: String) {
        Task {
            do {
                let audioData = try await voicevoxRepository.synthesize(text: text)
                print("音声合成完了: \(audioData.count) bytes")
            } catch {
                print("音声合成エラー: \(error)")
            }
        }
    }
    
}

// MARK: - AVAudioPlayerDelegate
extension CallViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            print("音声再生が終了しました")
            // ここで次のアクションを実行
            startSpeachRecognition()
        } else {
            print("音声再生に失敗しました")
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("音声デコードエラー: \(error?.localizedDescription ?? "不明なエラー")")
    }
}

