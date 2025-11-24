import Foundation

protocol SpeechRecognitionRepository {
    func requestPermission() async throws
    func startRecognition() async throws -> AsyncStream<String>
    func stopRecognition() async
    func isRecording() -> Bool
}