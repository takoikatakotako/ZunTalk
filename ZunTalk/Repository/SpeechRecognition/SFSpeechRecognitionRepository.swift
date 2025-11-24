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