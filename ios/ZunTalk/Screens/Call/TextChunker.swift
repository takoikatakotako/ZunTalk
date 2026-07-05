import Foundation

/// 音声合成のために長文を文単位のチャンクに分割する。
enum TextChunker {
    /// 「。」「！」「？」を区切りとして文単位に分割する。
    static func split(_ text: String) -> [String] {
        let delimiters: Set<Character> = ["。", "！", "？"]
        var chunks: [String] = []
        var currentChunk = ""

        for char in text {
            currentChunk.append(char)
            if delimiters.contains(char) {
                chunks.append(currentChunk)
                currentChunk = ""
            }
        }

        // 最後の残りがあれば追加
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks.filter { !$0.isEmpty }
    }
}
