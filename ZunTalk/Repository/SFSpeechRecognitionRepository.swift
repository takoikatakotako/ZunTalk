import Foundation

class SFSpeechRecognitionRepository: SpeechRecognitionRepository {
    private var isCurrentlyRecording = false
    
    func requestPermission() async throws {
        print("権限をリクエストしました")
    }
    
    func startRecognition() async throws -> AsyncStream<String> {
        print("音声認識を開始しました")
        isCurrentlyRecording = true
        
        return AsyncStream { continuation in
            continuation.yield("モック音声認識結果")
            continuation.finish()
        }
    }
    
    func stopRecognition() async {
        print("音声認識を停止しました")
        isCurrentlyRecording = false
    }
    
    func isRecording() -> Bool {
        return isCurrentlyRecording
    }
}

enum SpeechRecognitionError: Error, LocalizedError {
    case microphonePermissionDenied
    case speechRecognitionDenied
    case alreadyRecording
    case recognitionFailed
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "マイクへのアクセス権限が拒否されました"
        case .speechRecognitionDenied:
            return "音声認識の権限が拒否されました"
        case .alreadyRecording:
            return "既に音声認識中です"
        case .recognitionFailed:
            return "音声認識に失敗しました"
        }
    }
}