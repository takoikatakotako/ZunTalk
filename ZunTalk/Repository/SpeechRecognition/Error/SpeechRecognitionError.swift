import Foundation

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