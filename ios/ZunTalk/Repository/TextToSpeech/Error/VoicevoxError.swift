import Foundation

enum VoicevoxError: Error, LocalizedError {
    case onnxruntimeInitFailed
    case openJTalkRCNewFailed
    case synthesizerNewFailed
    case voiceModelFileOpenFailed
    case synthesizerLoadVoiceModelFailed
    case synthesizerTextToSpeechFailed
    case waveBufferNil
    
    var errorDescription: String? {
        switch self {
        case .onnxruntimeInitFailed:
            "Onnxruntime Init Failed"
        case .openJTalkRCNewFailed:
            "Open JTalk RC New Failed"
        case .synthesizerNewFailed:
            "Synthesizer New Failed"
        case .voiceModelFileOpenFailed:
            "Voice Model File Open Failed"
        case .synthesizerLoadVoiceModelFailed:
            "Synthesizer Load Voice Model Failed"
        case .synthesizerTextToSpeechFailed:
            "Synthesizer Text to Speech Failed"
        case .waveBufferNil:
            "Wave Buffer is nil"
        }
    }
}