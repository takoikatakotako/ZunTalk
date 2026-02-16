import Foundation
import voicevox_core

class VoicevoxRepository: TextToSpeechRepository {
    
    private var synthesizer: OpaquePointer?

    // MARK: - TextToSpeechRepository Implementation
    
    func installVoicevox() async throws {
        // リソースはバンドル内にフォルダ参照として配置されているため、
        // コピー不要。setupSynthesizer()で直接バンドルから読み込む。
        print("✅ VOICEVOX resources are ready in bundle (no copy needed)")

        // MIGRATION: v1.2.0 - 古いDocumentsディレクトリのリソースを削除
        // v1.3.0以降で削除予定
        try? await cleanupLegacyResources()
    }

    /// 古いバージョンでDocumentsにコピーしていたVOICEVOXリソースを削除
    /// - Note: v1.2.0で追加、v1.3.0以降で削除予定
    private func cleanupLegacyResources() async throws {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let legacyPaths = [
            documentsDirectory.appendingPathComponent("open_jtalk_dic_utf_8-1.11"),
            documentsDirectory.appendingPathComponent("vvms")
        ]

        for path in legacyPaths {
            if fileManager.fileExists(atPath: path.path) {
                do {
                    try fileManager.removeItem(at: path)
                    print("🗑️ Removed legacy resource: \(path.lastPathComponent)")
                } catch {
                    print("⚠️ Failed to remove legacy resource: \(path.lastPathComponent) - \(error.localizedDescription)")
                }
            }
        }
    }
    
    func setupSynthesizer() throws {
        // Generate VoicevoxInitializeOptions
        let initializeOptions: VoicevoxInitializeOptions = voicevox_make_default_initialize_options()
        print("Generate VoicevoxInitializeOptions")
        print("Acceleration Mode: %v\n", initializeOptions.acceleration_mode)
        print("Cpu Num Threads: %v\n", initializeOptions.cpu_num_threads)
        
        // Generate Onnxruntime
        var onnxruntime: OpaquePointer? = voicevox_onnxruntime_get()
        
        // Init Onnxruntime
        let onnxruntimeInitResultCode = voicevox_onnxruntime_init_once(&onnxruntime)
        print("OnnxruntimeInitResultCode: \(onnxruntimeInitResultCode)")
        guard onnxruntimeInitResultCode == 0 else {
            print("Onnxruntime Init Failed")
            throw VoicevoxError.onnxruntimeInitFailed
        }
        
        // Load Open JTalk (directly from bundle)
        let bundlePath = Bundle.main.resourcePath!
        let bundleURL = URL(fileURLWithPath: bundlePath)
        let openJTalkDirectoryName = "open_jtalk_dic_utf_8-1.11"
        let openJTalkDirectory = bundleURL.appendingPathComponent(openJTalkDirectoryName)
        let openJTalkDicDir: UnsafeMutablePointer<CChar>! = strdup(openJTalkDirectory.path())
        var openJtalk: OpaquePointer?
        let openJtalkRcNewResultCode: Int32 = voicevox_open_jtalk_rc_new(openJTalkDicDir, &openJtalk)
        guard openJtalkRcNewResultCode == 0 else {
            print("Open JTalk RC New Failed")
            throw VoicevoxError.openJTalkRCNewFailed
        }
        
        // Make Synthesizer
        // var synthesizer: OpaquePointer?
        let synthesizerNewResultCode = voicevox_synthesizer_new(onnxruntime, openJtalk, initializeOptions, &synthesizer)
        guard synthesizerNewResultCode == 0 else {
            print("Synthesizer New Failed")
            throw VoicevoxError.synthesizerNewFailed
        }
        voicevox_open_jtalk_rc_delete(openJtalk)
        
        
        // load model (directly from bundle)
        let voiceModelDirectoryName = "vvms"
        let vvmsDirectory = bundleURL.appendingPathComponent(voiceModelDirectoryName)
        let voiceModelFileName = "0.vvm"
        let voiceModelFileURL = vvmsDirectory.appendingPathComponent(voiceModelFileName)
        let voiceModelPath: UnsafeMutablePointer<CChar>! = strdup(voiceModelFileURL.path())
        var voiceModelFile: OpaquePointer?
        let voiceModelFileOpenResultCode: Int32 = voicevox_voice_model_file_open(voiceModelPath, &voiceModelFile)
        guard voiceModelFileOpenResultCode == 0 else {
            print("Voice Model File Open Failed")
            throw VoicevoxError.voiceModelFileOpenFailed
        }
        
        // load synthesizer model
        let synthesizerLoadVoiceModelResultCode = voicevox_synthesizer_load_voice_model(synthesizer, voiceModelFile)
        guard synthesizerLoadVoiceModelResultCode == 0 else {
            print("Synthesizer Load Voice Model Failed")
            throw VoicevoxError.synthesizerLoadVoiceModelFailed
        }
        voicevox_voice_model_file_delete(voiceModelFile)
    }
    
    func synthesize(text: String) async throws -> Data {
        
        // Generate
        let VoicevoxTtsOptions = voicevox_make_default_tts_options()
        let cText = strdup(text)
        defer { free(cText) }
        let styleId = 3
        var wavLength: UInt = 0
        var wavBuffer: UnsafeMutablePointer<UInt8>? = nil
        let synthesizerTtsResultCode = voicevox_synthesizer_tts(synthesizer, cText, VoicevoxStyleId(styleId), VoicevoxTtsOptions, &wavLength, &wavBuffer)
        guard synthesizerTtsResultCode == 0 else {
            print("Synthesizer Text to Speech Failed")
            throw VoicevoxError.synthesizerTextToSpeechFailed
        }
        
        // Load WAV Data
        guard let wavBuffer = wavBuffer else {
            print("Wave Buffer is nil")
            throw VoicevoxError.waveBufferNil
        }
        let data = Data(bytes: wavBuffer, count: Int(wavLength))

        // 解放（C側がmallocしてる想定）
        voicevox_wav_free(wavBuffer)
        
        return data
    }
    
    func cleanupSynthesizer() {
        if let synthesizer = synthesizer {
            print("Cleaning up synthesizer...")
            voicevox_synthesizer_delete(synthesizer)
            self.synthesizer = nil
        }
    }
    
    // MARK: - Lifecycle
    
    deinit {
        cleanupSynthesizer()
    }
    
}