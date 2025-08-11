import Foundation
import voicevox_core

class VoicevoxRepository: TextToSpeechRepository {
    
    private var synthesizer: OpaquePointer?

    // MARK: - TextToSpeechRepository Implementation
    
    func installVoicevox() async throws {
        // TODO: 実装予定 - 辞書ファイルやモデルファイルの配置処理
        
        // Resource URL
        let resourcePath = Bundle.main.resourcePath!
        let resourceURL = URL(fileURLWithPath: resourcePath)
        
        // Documents URL
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // リソースURL
        print("ResourcePath: \(resourceURL.path())")
        print("DocumentsPath: \(documentsURL.path())")
        
        // Create Voice Model Directory
        let voiceModelDirectoryName = "vvms"
        let vvmsDirectory = documentsURL.appendingPathComponent(voiceModelDirectoryName)
        try! createDirectoryIfNotExist(at: vvmsDirectory)
        print("VoiceModelDirectoryPath: \(vvmsDirectory.path())")
        
        // Copy to Voice Model File
        let voiceModelFileName = "0.vvm"
        let voiceModelFileURL = vvmsDirectory.appendingPathComponent(voiceModelFileName)
        try! copyFile(
            from: resourceURL.appendingPathComponent(voiceModelFileName),
            to: voiceModelFileURL
        )
        print("VoiceFilePath: \(voiceModelFileURL.path())")
        
        // Copy to Open JTalk
        let openJTalkDirectoryName = "open_jtalk_dic_utf_8-1.11"
        let openJTalkDirectory = documentsURL.appendingPathComponent(openJTalkDirectoryName)
        try! createDirectoryIfNotExist(at: openJTalkDirectory)
        print("OpenJTalkDirectoryPath: \(openJTalkDirectory.path())")
        
        // Copy to Open JTalkFiles
        let openJTalkFilenames = ["char.bin", "COPYING", "left-id.def", "matrix.bin", "pos-id.def", "rewrite.def", "right-id.def", "sys.dic", "unk.dic"]
        for filename in openJTalkFilenames {
            let fileURL = openJTalkDirectory.appendingPathComponent(filename)
            try! copyFile(
                from: resourceURL.appendingPathComponent(filename),
                to: fileURL
            )
            print("OpenJTalkFilePath(\(filename): \(fileURL.path())")
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
        
        // Load Open JTalk
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let openJTalkDirectoryName = "open_jtalk_dic_utf_8-1.11"
        let openJTalkDirectory = documentsURL.appendingPathComponent(openJTalkDirectoryName)
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
        
        
        // load model
        let voiceModelDirectoryName = "vvms"
        let vvmsDirectory = documentsURL.appendingPathComponent(voiceModelDirectoryName)
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
            print("Synthesizer Text to Speach Failed")
            throw VoicevoxError.synthesizerTextToSpeachFailed
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
    
    // MARK: - Private Methods
    
    private func createDirectoryIfNotExist(at url: URL) throws {
         // すでに存在していれば何もしない
         if FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
             return
         }
         try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
     }
     
     private func copyFile(from sourceURL: URL, to destinationURL: URL) throws {
         // すでにファイルが存在していたらスキップ
         if FileManager.default.fileExists(atPath: destinationURL.path) {
             return
         }
         try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
     }
}