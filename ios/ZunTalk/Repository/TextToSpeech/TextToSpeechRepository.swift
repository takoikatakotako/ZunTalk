import Foundation

protocol TextToSpeechRepository {
    func installVoicevox() async throws
    func setupSynthesizer() throws
    func synthesize(text: String) async throws -> Data
    func cleanupSynthesizer()
}
