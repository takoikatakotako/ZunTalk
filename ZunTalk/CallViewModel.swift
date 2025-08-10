import SwiftUI
import Speech
import Accelerate

class CallViewModel: ObservableObject {
    
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

    
//    
//    var speechRecognizer:SFSpeechRecognizer?
////    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
//    var recognitionTask: SFSpeechRecognitionTask?
//    
    
    func onAppear() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            print("認証済み")
        case .denied:
            print("許可が得られませんでした")
            return
        case .restricted:
            print("利用制限があります")
            return
        case .notDetermined:
            print("認証が未決定")
            return
        @unknown default:
            print("不明")
            return
        }
        
        
        
        guard let asset = NSDataAsset(name: "maou_se_sound_phone02") else {
            print("音声ファイルが見つかりません")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(data: asset.data)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            print("再生開始")
        } catch {
            print("再生エラー: \(error.localizedDescription)")
        }
        
        
        
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch let error {
            print(error)
        }
        
        let input = engine.inputNode

        
//        
//        let input = engine.inputNode
//        let format = input.outputFormat(forBus: 0)
//        input.removeTap(onBus: 0)
//        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in
//            self.request?.append(buf)
//            self.detectSilence(buf)
//        }
//        
        
//
        
        //
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        request.shouldReportPartialResults = true // 発話ごとに中間結果を返すかどうか
                
        // requiresOnDeviceRecognition を true に設定すると、音声データがネットワークで送られない
        // ただし精度は下がる
        request.requiresOnDeviceRecognition = false
        
        
        
        
        // 既存のタスクがあればキャンセルしておく
        self.task?.cancel()
        self.task = nil

        self.task = recognizer?.recognitionTask(with: request) { result, error in

            // 取得した認識結の処理

            var isFinal = false
                    
            if let result = result {
                isFinal = result.isFinal
                
                                
                // 認識結果をプリント
                print("RecognizedText: \(result.bestTranscription.formattedString)")
                
                Task { @MainActor in
                    self.text = result.bestTranscription.formattedString
                    self.audioPlayer?.volume = 0
                }
            }
                    
            if error != nil || isFinal {
                // 終了時、もしくはエラーが出た場合は、音声取得と認識をストップする
                self.engine.stop()
                input.removeTap(onBus: 0)
                        
                self.request = nil
                self.task = nil
            }
        }
        
        
        
        
        let recordingFormat = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
//          // 音声を取得したら
//            func isSpeaking(buffer: AVAudioPCMBuffer, threshold: Float = 0.05) -> Bool {
//                // buffer.floatChannelData は [チャネル][サンプル]
//                guard let channelData = buffer.floatChannelData?[0] else {
//                    return false
//                }
//                let frameLength = Int(buffer.frameLength)
//
//                // 平均絶対値（RMSでも可）
//                var avg: Float = 0.0
//                vDSP_meamgv(channelData, 1, &avg, vDSP_Length(frameLength))
//
//                return avg > threshold
//            }
//            
//            if isSpeaking(buffer: buffer) {
//                print("min")
//                self.audioPlayer?.volume = 0
//            }
//            
//            
            
            
            
            print("hellohello")
            self.request?.append(buffer) // 認識リクエストに取得した音声を加える
        }
        
        
        engine.prepare()
        
        
        do {
            try engine.start()
        } catch {
            print("エラー: \(error.localizedDescription)")
        }
        
        
    }
    
    
    
    
    

    func startOrStop() {
        if isRecording { stop(); return }

        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in
            self.request?.append(buf)
            self.detectSilence(buf)
        }

        task = recognizer?.recognitionTask(with: request!) { result, error in
            if let r = result { DispatchQueue.main.async { self.text = r.bestTranscription.formattedString } }
            if error != nil || result?.isFinal == true { self.stop() }
        }

        try? AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
        isRecording = true
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        isRecording = false
        silenceTimer?.invalidate()
    }

    private func detectSilence(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let rms = sqrt(stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
            .map { data[$0] * data[$0] }.reduce(0,+) / Float(buffer.frameLength))
        if rms < silenceThreshold {
            silenceTimer?.invalidate()
            silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTime, repeats: false) { _ in self.stop() }
        } else {
            silenceTimer?.invalidate()
        }
    }
    
}

