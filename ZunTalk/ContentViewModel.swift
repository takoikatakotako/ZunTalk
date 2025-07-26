import SwiftUI
import Speech

class ContentViewModel: ObservableObject {
    
    func onAppear() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("認証済み")
                self.startOrStop()
            case .denied:
                print("許可が得られませんでした")
            case .restricted:
                print("利用制限があります")
            case .notDetermined:
                print("認証が未決定")
            @unknown default:
                print("未知のエラー")
            }
        }
    }
    
    
    
    
    @Published var text = ""
    @Published var isRecording = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?

    private let silenceThreshold: Float = 0.01
    private let silenceTime: TimeInterval = 2.0

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

