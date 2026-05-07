import Foundation

enum CallError: LocalizedError {
    case speechRecognitionPermissionDenied
    case audioPlaybackFailed
    case speechRecognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .speechRecognitionPermissionDenied:
            return "音声認識の許可が得られませんでした"
        case .audioPlaybackFailed:
            return "音声の再生に失敗しました"
        case .speechRecognitionFailed(let error):
            return "音声認識に失敗しました: \(error.localizedDescription)"
        }
    }
}
