import Foundation
import AppKit
import Compression

enum WordListType: String, CaseIterable {
    case full = "full"
    case common = "common"

    var displayName: String {
        switch self {
        case .common: return "Common 7-Letter Words"
        case .full: return "Full NASPA Word List"
        }
    }

    var filename: String {
        switch self {
        case .common: return "01_common"
        case .full: return "02_full"
        }
    }
}

class Lexicon {
    private var words: Set<String> = []
    private var definitions: [String: String] = [:]  // word -> definition
    private var sevenLetterWords: [String] = []
    private var anagramGroups: [String: [String]] = [:]  // sorted letters -> list of words
    private(set) var currentWordList: WordListType = .full

    var wordCount: Int { words.count }

    init() {}

    func load(wordList: WordListType = .full) -> Bool {
        currentWordList = wordList
        let filename = wordList.filename

        // Try .gz file first (compressed format for distribution)
        if let url = Bundle.main.url(forResource: filename, withExtension: "gz") {
            return loadCompressedFile(at: url)
        }

        // Fall back to Resources/WordLists directory for .gz
        let gzPath = Bundle.main.bundlePath + "/Contents/Resources/WordLists/\(filename).gz"
        if FileManager.default.fileExists(atPath: gzPath) {
            return loadCompressedFile(at: URL(fileURLWithPath: gzPath))
        }

        // Fall back to .txt for development
        if let url = Bundle.main.url(forResource: filename, withExtension: "txt") {
            return loadFile(at: url)
        }

        let txtPath = Bundle.main.bundlePath + "/Contents/Resources/WordLists/\(filename).txt"
        if FileManager.default.fileExists(atPath: txtPath) {
            return loadFile(at: URL(fileURLWithPath: txtPath))
        }

        return false
    }

    private func loadCompressedFile(at url: URL) -> Bool {
        do {
            let compressedData = try Data(contentsOf: url)
            guard let decompressedData = decompressGzip(data: compressedData),
                  let content = String(data: decompressedData, encoding: .utf8) else {
                print("Failed to decompress word list")
                return false
            }
            processWordList(content)
            precomputeAnagramGroups()
            return true
        } catch {
            print("Failed to load compressed lexicon: \(error)")
            return false
        }
    }

    private func decompressGzip(data: Data) -> Data? {
        // Gzip format: 10-byte header, compressed data, 8-byte trailer (CRC32 + size)
        guard data.count > 18 else { return nil }

        // Verify gzip magic number
        guard data[0] == 0x1f && data[1] == 0x8b else { return nil }

        // Find where the compressed data starts (skip header)
        var headerSize = 10
        let flags = data[3]

        // Check for optional fields in header
        if flags & 0x04 != 0 {  // FEXTRA
            guard data.count > headerSize + 2 else { return nil }
            let extraLen = Int(data[headerSize]) + Int(data[headerSize + 1]) << 8
            headerSize += 2 + extraLen
        }
        if flags & 0x08 != 0 {  // FNAME - null-terminated string
            while headerSize < data.count && data[headerSize] != 0 { headerSize += 1 }
            headerSize += 1
        }
        if flags & 0x10 != 0 {  // FCOMMENT - null-terminated string
            while headerSize < data.count && data[headerSize] != 0 { headerSize += 1 }
            headerSize += 1
        }
        if flags & 0x02 != 0 {  // FHCRC
            headerSize += 2
        }

        guard data.count > headerSize + 8 else { return nil }

        // Extract compressed payload (exclude header and 8-byte trailer)
        let compressedPayload = data.subdata(in: headerSize..<(data.count - 8))

        // Get uncompressed size from trailer (last 4 bytes, little-endian)
        let sizeOffset = data.count - 4
        let uncompressedSize = Int(data[sizeOffset]) |
                              Int(data[sizeOffset + 1]) << 8 |
                              Int(data[sizeOffset + 2]) << 16 |
                              Int(data[sizeOffset + 3]) << 24

        // Allocate buffer for decompressed data
        var destBuffer = [UInt8](repeating: 0, count: uncompressedSize)

        let result = compressedPayload.withUnsafeBytes { srcPtr -> Int in
            destBuffer.withUnsafeMutableBytes { destPtr -> Int in
                return compression_decode_buffer(
                    destPtr.bindMemory(to: UInt8.self).baseAddress!,
                    uncompressedSize,
                    srcPtr.bindMemory(to: UInt8.self).baseAddress!,
                    compressedPayload.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard result > 0 else { return nil }
        return Data(destBuffer.prefix(result))
    }

    func switchWordList(to wordList: WordListType) -> Bool {
        return load(wordList: wordList)
    }

    private func loadFile(at url: URL) -> Bool {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            processWordList(content)
            precomputeAnagramGroups()
            return true
        } catch {
            print("Failed to load lexicon: \(error)")
            return false
        }
    }

    private func processWordList(_ content: String) {
        words.removeAll()
        definitions.removeAll()
        sevenLetterWords.removeAll()

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            // Format: WORD<TAB>definition
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard !parts.isEmpty else { continue }

            let word = String(parts[0]).uppercased().trimmingCharacters(in: .whitespaces)
            guard word.count >= 3 && word.count <= 7 else { continue }
            guard word.allSatisfy({ $0.isLetter }) else { continue }

            words.insert(word)

            // Store definition if present
            if parts.count > 1 {
                definitions[word] = String(parts[1]).trimmingCharacters(in: .whitespaces)
            }

            if word.count == 7 {
                sevenLetterWords.append(word)
            }
        }
    }

    private func precomputeAnagramGroups() {
        // Group 7-letter words by their sorted letters
        anagramGroups.removeAll()

        for word in sevenLetterWords {
            let sortedKey = String(word.sorted())
            if anagramGroups[sortedKey] == nil {
                anagramGroups[sortedKey] = []
            }
            anagramGroups[sortedKey]!.append(word)
        }
    }

    func getDefinition(for word: String) -> String? {
        return definitions[word.uppercased()]
    }

    func isValidWord(_ word: String) -> Bool {
        return words.contains(word.uppercased())
    }

    func getRandomSevenLetterWord() -> String? {
        return sevenLetterWords.randomElement()
    }

    /// Get all 7-letter words that are anagrams of the given word
    func getSevenLetterAnagrams(for letters: [Character]) -> [String] {
        let sortedKey = String(letters.sorted())
        return anagramGroups[sortedKey] ?? []
    }

    /// Get a random 7-letter word that has multiple bingo anagrams (2+)
    func getMultiBingoWord() -> String? {
        // Find all anagram groups with 2+ words
        let multiBingoGroups = anagramGroups.filter { $0.value.count >= 2 }
        guard !multiBingoGroups.isEmpty else { return nil }

        // Pick a random group and return a random word from it
        let randomGroup = multiBingoGroups.randomElement()!
        return randomGroup.value.randomElement()
    }

    func findAllAnagrams(from letters: [Character]) -> [String: Int] {
        var result: [String: Int] = [:]
        let letterCounts = countLetters(letters)

        for word in words {
            if canFormWord(word, from: letterCounts) {
                result[word] = word.count
            }
        }

        return result
    }

    private func countLetters(_ letters: [Character]) -> [Character: Int] {
        var counts: [Character: Int] = [:]
        for letter in letters {
            counts[letter, default: 0] += 1
        }
        return counts
    }

    private func canFormWord(_ word: String, from availableCounts: [Character: Int]) -> Bool {
        var counts = availableCounts

        for char in word.uppercased() {
            if let count = counts[char], count > 0 {
                counts[char] = count - 1
            } else {
                return false
            }
        }

        return true
    }
}
