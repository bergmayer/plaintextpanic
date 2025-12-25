import Foundation
import AppKit
import Combine

enum GameMode {
    case titleScreen
    case playing
    case revealing  // Shows all words after round ends
    case gameOver
    case highScoreEntry  // Entering initials for high score
    case highScoreList  // Viewing high score list
}

enum LetterColor: String, CaseIterable {
    case green = "green"
    case amber = "amber"
    case white = "white"
}

struct HighScoreEntry: Codable {
    var initials: String
    var score: Int
    var round: Int
}

class GameEngine: ObservableObject {
    @Published var buffer: [[Character]] = Array(repeating: Array(repeating: Character(" "), count: 40), count: 24)
    @Published var gameMode: GameMode = .titleScreen
    @Published var cursorVisible: Bool = true  // For blinking cursor
    @Published var timeBonusDisplay: String? = nil  // Shows "+20", "+10", "+5" briefly
    #if DEBUG
    @Published var isDebugMode: Bool = false  // Debug mode - red text, debug commands enabled
    #else
    let isDebugMode: Bool = false  // Always false in release builds
    #endif
    @Published var currentWordList: WordListType = .school  // Current word list selection
    @Published var letterColor: LetterColor = .green  // Letter color preference

    // Flash screen state (BINGO/WOW rendered to buffer)
    private var savedBuffer: [[Character]]? = nil
    private var isShowingBingoFlash: Bool = false
    private var isShowingWowFlash: Bool = false
    #if DEBUG
    private var isShowingDebugHelp: Bool = false  // Showing debug help overlay
    #endif

    // Game state
    var score: Int = 0
    var roundScore: Int = 0  // Score earned in current round
    var timeLeft: Int = 120
    var level: Int = 1
    var pool: [Character] = []
    var poolDisplay: [Character] = []  // Pool with typed letters removed
    var userInput: String = ""
    var foundWords: Set<String> = []
    var allValidWords: [String: Int] = [:]
    var statusMessage: String = ""
    var bingoWords: [String] = []  // All possible 7-letter words for this pool
    var foundBingos: Set<String> = []  // Which bingos have been found
    var revealScrollOffset: Int = 0  // Scroll offset for reveal screen
    var gameScrollOffset: Int = 0  // Scroll offset for gameplay word matrix
    var bingoScrollOffset: Int = 0  // Horizontal scroll offset for bingos
    var highScores: [HighScoreEntry] = []  // High score list
    #if DEBUG
    private var isStressTestMode: Bool = false  // Flag for stress test display mode
    #else
    private let isStressTestMode: Bool = false  // Always false in release builds
    #endif
    var highScoreInitials: String = ""  // Initials being entered for high score
    private var cameFromRevealScreen: Bool = false  // Track if high scores accessed mid-game
    #if DEBUG
    private var stressTestWordCounts: [Int: Int] = [:]  // Track submitted words per length in stress test
    #endif

    private var lexicon = Lexicon()
    private let highScoresKey = "PlaintextPanicHighScores"
    private let wordListKey = "PlaintextPanicWordList"
    private let letterColorKey = "PlaintextPanicLetterColor"
    private let minScoreRequired = 450  // Minimum points per round to continue
    private let maxHighScores = 10
    private var timer: Timer?
    private var cursorTimer: Timer?
    private var definitionsWindowController = DefinitionsWindowController()

    init() {
        // Load word list preference
        if let savedList = UserDefaults.standard.string(forKey: wordListKey),
           let listType = WordListType(rawValue: savedList) {
            currentWordList = listType
        }
        // Load letter color preference
        if let savedColor = UserDefaults.standard.string(forKey: letterColorKey),
           let colorType = LetterColor(rawValue: savedColor) {
            letterColor = colorType
        }
        _ = lexicon.load(wordList: currentWordList)
        loadHighScores()
        startCursorBlink()
        showTitleScreen()
    }

    private func startCursorBlink() {
        cursorTimer?.invalidate()
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.cursorVisible.toggle()
            if self?.gameMode == .playing {
                self?.refreshGameDisplay()
            }
        }
    }

    // MARK: - High Scores

    private func loadHighScores() {
        if let data = UserDefaults.standard.data(forKey: highScoresKey),
           let scores = try? JSONDecoder().decode([HighScoreEntry].self, from: data) {
            highScores = scores
        }
    }

    private func saveHighScores() {
        if let data = try? JSONEncoder().encode(highScores) {
            UserDefaults.standard.set(data, forKey: highScoresKey)
        }
    }

    private func isHighScore(_ score: Int) -> Bool {
        if highScores.count < maxHighScores {
            return score > 0
        }
        return score > (highScores.last?.score ?? 0)
    }

    private func addHighScore(initials: String, score: Int, round: Int) {
        let entry = HighScoreEntry(initials: initials.uppercased(), score: score, round: round)
        highScores.append(entry)
        highScores.sort { $0.score > $1.score }
        if highScores.count > maxHighScores {
            highScores = Array(highScores.prefix(maxHighScores))
        }
        saveHighScores()
    }

    func resetHighScores() {
        highScores.removeAll()
        saveHighScores()
    }

    // MARK: - Word List Management

    func switchWordList(to listType: WordListType) {
        guard gameMode == .titleScreen else { return }  // Only allow switching from title screen
        currentWordList = listType
        UserDefaults.standard.set(listType.rawValue, forKey: wordListKey)
        _ = lexicon.switchWordList(to: listType)
        showTitleScreen()  // Refresh to show any changes
    }

    func switchLetterColor(to color: LetterColor) {
        letterColor = color
        UserDefaults.standard.set(color.rawValue, forKey: letterColorKey)
    }

    // MARK: - Debug

    #if DEBUG
    /// Toggle debug mode (Ctrl+Cmd+Opt+D from title screen)
    func toggleDebugMode() {
        guard gameMode == .titleScreen || isShowingDebugHelp else { return }

        if isShowingDebugHelp {
            // Dismiss debug help
            isShowingDebugHelp = false
            showTitleScreen()
            return
        }

        isDebugMode = !isDebugMode
        if isDebugMode {
            showDebugHelp()
        } else {
            showTitleScreen()
        }
    }

    /// Dismiss debug help screen (ESC)
    func dismissDebugHelp() -> Bool {
        guard isShowingDebugHelp else { return false }
        isShowingDebugHelp = false
        showTitleScreen()
        return true
    }

    private func showDebugHelp() {
        isShowingDebugHelp = true
        clearBuffer()

        writeString(String(repeating: "+", count: 40), row: 0, col: 0)
        writeCentered("+++ DEBUG MODE ACTIVE +++", row: 1)
        writeString(String(repeating: "+", count: 40), row: 2, col: 0)

        writeCentered("COMMANDS (Ctrl+Cmd+Option+):", row: 5)
        writeString("  D - Toggle debug mode", row: 7, col: 6)
        writeString("  W - Complete round (WOW)", row: 8, col: 6)
        writeString("  B - Find next bingo", row: 9, col: 6)
        writeString("  7 - New round with AEINRST", row: 10, col: 6)
        writeString("  X - Stress test (many words)", row: 11, col: 6)

        writeString(String(repeating: "-", count: 40), row: 14, col: 0)
        writeCentered("[ESC] DISMISS", row: 16)
    }

    /// Debug function to start a round with AEINRST letters (Ctrl+Cmd+Opt+7)
    /// AEINRST has many possible bingos - useful for testing multi-bingo display
    func debugStartMultiBingoRound() {
        guard isDebugMode else { return }
        guard gameMode == .playing || gameMode == .titleScreen else { return }

        // Use AEINRST - a set of letters with many possible 7-letter bingos
        let testLetters: [Character] = ["A", "E", "I", "N", "R", "S", "T"]

        // Start/restart round with these letters
        stopTimer()
        pool = testLetters
        pool.shuffle()
        poolDisplay = pool
        userInput = ""
        roundScore = 0
        foundWords.removeAll()
        foundBingos.removeAll()
        allValidWords = lexicon.findAllAnagrams(from: pool)
        gameScrollOffset = 0
        bingoScrollOffset = 0
        bingoWords = lexicon.getSevenLetterAnagrams(for: pool).sorted()
        timeLeft = 120
        statusMessage = "* DEBUG: \(bingoWords.count) BINGOS *"
        gameMode = .playing

        refreshGameDisplay()
        startTimer()
    }

    /// Debug function to simulate finding all words (Ctrl+Cmd+Opt+W)
    func debugSimulatePerfectRound() {
        guard isDebugMode else { return }
        guard gameMode == .playing, !isShowingBingoFlash, !isShowingWowFlash else { return }

        // Mark all words as found
        for (word, _) in allValidWords {
            foundWords.insert(word)
        }

        // Mark all bingos as found
        for bingo in bingoWords {
            foundBingos.insert(bingo)
        }

        // Calculate score for all words
        var totalPoints = 0
        for (_, length) in allValidWords {
            totalPoints += scoreForWord(length: length)
        }
        roundScore = totalPoints
        score += totalPoints

        // Stop timer and show WOW screen
        stopTimer()
        showWowScreen()
    }

    /// Debug function to simulate finding a bingo (Ctrl+Cmd+Opt+B)
    func debugSimulateBingo() {
        guard isDebugMode else { return }
        guard gameMode == .playing, !isShowingBingoFlash, !isShowingWowFlash else { return }
        guard let bingo = bingoWords.first(where: { !foundBingos.contains($0) }) else { return }

        // Mark bingo as found
        foundWords.insert(bingo)
        foundBingos.insert(bingo)

        // Add score
        let points = scoreForWord(length: 7)
        score += points
        roundScore += points

        // Apply time bonus (+21 seconds, shown as +20)
        timeLeft += 21
        timeBonusDisplay = "+20"

        // Show bingo flash
        triggerBingoFlash()

        statusMessage = "* BINGO! \"\(bingo)\" +\(points) PTS *"
        refreshGameDisplay()

        // Clear time bonus display after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.timeBonusDisplay = nil
            self?.refreshGameDisplay()
        }

        // Clear status message after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if self.statusMessage.contains(bingo) {
                self.statusMessage = ""
                self.refreshGameDisplay()
            }
        }
    }

    /// Debug function to start stress test mode (Ctrl+Cmd+Opt+X)
    /// Populates display with many dummy words to test scrolling and layout
    /// Every typed word is valid until all slots for that length are filled
    func debugStartStressTest() {
        guard isDebugMode else { return }
        guard gameMode == .playing || gameMode == .revealing else { return }

        isStressTestMode = true

        // Clear existing data
        allValidWords.removeAll()
        foundWords.removeAll()
        bingoWords.removeAll()
        foundBingos.removeAll()
        stressTestWordCounts = [3: 0, 4: 0, 5: 0, 6: 0, 7: 0]

        // Generate 500 3-letter dummy words (all start unfound)
        for i in 0..<500 {
            let prefixChar = Character(UnicodeScalar(65 + (i / 100))!)  // A, B, C, D, E
            let word = "\(prefixChar)\(String(format: "%02d", i % 100))"
            allValidWords[word] = 3
        }

        // Generate 400 4-letter dummy words
        for i in 0..<400 {
            let prefixChar = Character(UnicodeScalar(65 + (i / 100))!)  // A, B, C, D
            let word = "A\(prefixChar)\(String(format: "%02d", i % 100))"
            allValidWords[word] = 4
        }

        // Generate 300 5-letter dummy words
        for i in 0..<300 {
            let prefixChar = Character(UnicodeScalar(65 + (i / 100))!)  // A, B, C
            let word = "AA\(prefixChar)\(String(format: "%02d", i % 100))"
            allValidWords[word] = 5
        }

        // Generate 200 6-letter dummy words
        for i in 0..<200 {
            let prefixChar = Character(UnicodeScalar(65 + (i / 100))!)  // A, B
            let word = "AAA\(prefixChar)\(String(format: "%02d", i % 100))"
            allValidWords[word] = 6
        }

        // Generate 100 7-letter bingos
        for i in 0..<100 {
            let word = "AAAA\(String(format: "%03d", i))"
            allValidWords[word] = 7
            bingoWords.append(word)
        }

        bingoWords.sort()
        bingoScrollOffset = 0
        gameScrollOffset = 0
        revealScrollOffset = 0

        if gameMode == .playing {
            pool = Array("XXXXXXX")
            poolDisplay = pool
            userInput = ""
            statusMessage = "* STRESS TEST MODE *"
            refreshGameDisplay()
        } else if gameMode == .revealing {
            // For reveal screen stress test, show all as found for display testing
            for (word, _) in allValidWords {
                foundWords.insert(word)
            }
            for bingo in bingoWords {
                foundBingos.insert(bingo)
            }
            refreshRevealDisplay()
        }
    }
    #endif

    // MARK: - Buffer Management

    private func clearBuffer() {
        objectWillChange.send()
        for row in 0..<24 {
            for col in 0..<40 {
                buffer[row][col] = " "
            }
        }
    }

    private func writeString(_ text: String, row: Int, col: Int) {
        guard row >= 0 && row < 24 else { return }
        var currentCol = col
        for char in text {
            guard currentCol >= 0 && currentCol < 40 else { break }
            buffer[row][currentCol] = char
            currentCol += 1
        }
    }

    private func writeCentered(_ text: String, row: Int) {
        let startCol = max(0, (40 - text.count) / 2)
        writeString(text, row: row, col: startCol)
    }

    // MARK: - Screens

    func showTitleScreen() {
        stopTimer()
        #if DEBUG
        isStressTestMode = false
        #endif
        gameMode = .titleScreen
        clearBuffer()

        writeString(String(repeating: "+", count: 40), row: 0, col: 0)
        writeCentered("PLAINTEXT PANIC", row: 1)
        writeString(String(repeating: "+", count: 40), row: 2, col: 0)

        writeCentered("FIND WORDS", row: 4)
        writeCentered("EACH ROUND IS 2 MINUTES", row: 5)
        writeCentered("TIME BONUS FOR 5, 6, AND 7-LETTER WORDS", row: 6)
        writeCentered("FIND THE 7-LETTER BINGO", row: 7)
        writeCentered("SCORE 450+ POINTS TO CONTINUE!", row: 8)

        writeString(String(repeating: "-", count: 40), row: 10, col: 0)
        writeCentered("SCORING:", row: 11)
        writeString("3-LETTER: 50", row: 12, col: 2)
        writeString("4-LETTER: 75", row: 12, col: 21)
        writeString("5-LETTER: 100", row: 13, col: 2)
        writeString("6-LETTER: 200", row: 13, col: 21)
        writeCentered("7-LETTER: 300", row: 14)

        writeString(String(repeating: "-", count: 40), row: 16, col: 0)

        writeCentered("[ENTER] START   [H] HIGH SCORES", row: 18)
        writeCentered("[CMD-Q] QUIT", row: 19)
    }

    private func refreshGameDisplay() {
        // Don't refresh if showing a flash screen
        guard !isShowingBingoFlash, !isShowingWowFlash else { return }

        clearBuffer()

        // Line 0-2: Title
        writeString(String(repeating: "+", count: 40), row: 0, col: 0)
        writeCentered("PLAINTEXT PANIC", row: 1)
        writeString(String(repeating: "+", count: 40), row: 2, col: 0)

        // Line 3: Score (left), Round (center), Time (right)
        writeString(String(format: "SCORE:%03d", roundScore), row: 3, col: 1)
        writeCentered(String(format: "ROUND:%02d", level), row: 3)
        // Show time bonus display or actual time
        if let bonus = timeBonusDisplay {
            writeString("TIME: \(bonus)", row: 3, col: 31)
        } else {
            writeString(String(format: "TIME:%03d", timeLeft), row: 3, col: 31)
        }

        // Line 4: Separator
        writeString(String(repeating: "-", count: 40), row: 4, col: 0)

        // Line 5-6: Column headers
        writeString(" 3-LTRS    4-LTRS    5-LTRS    6-LTRS", row: 5, col: 0)
        writeString(" ------    ------    ------    ------", row: 6, col: 0)

        // Lines 7-14: Word Matrix
        renderWordMatrix()

        // Line 15-16: Bingo area (multi-bingo support)
        renderBingoArea()

        // Line 17: Separator
        writeString(String(repeating: "-", count: 40), row: 17, col: 0)

        // Line 19: Pool letters (wide spacing, typed letters become spaces)
        let poolStr = poolDisplay.map { String($0) }.joined(separator: "   ")
        writeCentered(poolStr, row: 19)

        // Line 21: Input
        // Use block cursor (█) when visible, space when not
        let cursor = cursorVisible ? "\u{2588}" : " "  // █ or space
        let inputDisplay = "INPUT: > \(userInput)\(cursor)"
        writeString(inputDisplay, row: 21, col: 1)

        // Line 22: Separator
        writeString(String(repeating: "-", count: 40), row: 22, col: 0)

        // Line 23: Status
        if !statusMessage.isEmpty {
            writeCentered(statusMessage, row: 23)
        } else {
            writeCentered("[SPACE] SHUFFLE  [ESC] END ROUND", row: 23)
        }
    }

    private func refreshRevealDisplay() {
        clearBuffer()

        // Line 0-2: Title
        writeString(String(repeating: "+", count: 40), row: 0, col: 0)
        writeCentered("ROUND COMPLETE", row: 1)
        writeString(String(repeating: "+", count: 40), row: 2, col: 0)

        // Line 3: Round score and total
        let scoreStr = String(format: " ROUND:%02d  +%03d PTS  TOTAL:%06d", level, roundScore, score)
        writeString(scoreStr, row: 3, col: 0)

        // Line 4: Separator
        writeString(String(repeating: "-", count: 40), row: 4, col: 0)

        // Line 5-6: Column headers
        writeString(" 3-LTRS    4-LTRS    5-LTRS    6-LTRS", row: 5, col: 0)
        writeString(" ------    ------    ------    ------", row: 6, col: 0)

        // Lines 7-14: Full word matrix (with scroll)
        renderRevealWordMatrix()

        // Line 15: Separator
        writeString(String(repeating: "-", count: 40), row: 15, col: 0)

        // Line 16-20: All bingos
        renderRevealBingos()

        // Line 21: Separator or scroll indicator
        let isScrollable = getMaxWordCount() > 8
        if isScrollable {
            writeCentered("[UP/DOWN] SCROLL", row: 21)
        } else {
            writeString(String(repeating: "-", count: 40), row: 21, col: 0)
        }

        // Line 22-23: Instructions based on score
        if roundScore >= minScoreRequired {
            writeCentered("[ENTER] NEXT ROUND   [D] DEFINITIONS", row: 22)
        } else {
            writeCentered("NOT ENOUGH POINTS TO CONTINUE", row: 22)
        }
        writeCentered("[ESC] END   [H] HIGH SCORES", row: 23)
    }

    private func renderRevealWordMatrix() {
        // Get all words by length, sorted alphabetically
        var words3: [String] = []
        var words4: [String] = []
        var words5: [String] = []
        var words6: [String] = []

        for (word, length) in allValidWords {
            if length == 7 { continue }
            switch length {
            case 3: words3.append(word)
            case 4: words4.append(word)
            case 5: words5.append(word)
            case 6: words6.append(word)
            default: break
            }
        }

        // Sort all lists
        words3.sort()
        words4.sort()
        words5.sort()
        words6.sort()

        // Mark found words with * prefix
        func formatWord(_ word: String) -> String {
            if foundWords.contains(word) {
                return word  // Found words shown normally
            } else {
                return word.lowercased()  // Unfound words in lowercase
            }
        }

        let display3 = words3.map { formatWord($0) }
        let display4 = words4.map { formatWord($0) }
        let display5 = words5.map { formatWord($0) }
        let display6 = words6.map { formatWord($0) }

        let maxRows = 8
        let offset = revealScrollOffset

        // Calculate how many more items are below visible area for each column
        func remainingBelow(_ displayList: [String]) -> Int {
            let lastVisibleIdx = offset + maxRows - 1
            if displayList.count > lastVisibleIdx + 1 {
                return displayList.count - lastVisibleIdx - 1
            }
            return 0
        }

        let remaining3 = remainingBelow(display3)
        let remaining4 = remainingBelow(display4)
        let remaining5 = remainingBelow(display5)
        let remaining6 = remainingBelow(display6)

        for i in 0..<maxRows {
            var line = " "
            let idx = i + offset
            let isLastRow = (i == maxRows - 1)

            // 3-letter column (width 10)
            if isLastRow && remaining3 > 0 {
                line += "+\(remaining3) MORE".padding(toLength: 10, withPad: " ", startingAt: 0)
            } else if idx < display3.count {
                line += display3[idx].padding(toLength: 10, withPad: " ", startingAt: 0)
            } else {
                line += String(repeating: " ", count: 10)
            }

            // 4-letter column (width 10)
            if isLastRow && remaining4 > 0 {
                line += "+\(remaining4) MORE".padding(toLength: 10, withPad: " ", startingAt: 0)
            } else if idx < display4.count {
                line += display4[idx].padding(toLength: 10, withPad: " ", startingAt: 0)
            } else {
                line += String(repeating: " ", count: 10)
            }

            // 5-letter column (width 10)
            if isLastRow && remaining5 > 0 {
                line += "+\(remaining5) MORE".padding(toLength: 10, withPad: " ", startingAt: 0)
            } else if idx < display5.count {
                line += display5[idx].padding(toLength: 10, withPad: " ", startingAt: 0)
            } else {
                line += String(repeating: " ", count: 10)
            }

            // 6-letter column (width 9)
            if isLastRow && remaining6 > 0 {
                line += "+\(remaining6) MORE"
            } else if idx < display6.count {
                line += display6[idx]
            }

            writeString(line, row: 7 + i, col: 0)
        }
    }

    private func renderRevealBingos() {
        if bingoWords.isEmpty {
            writeCentered("NO BINGOS POSSIBLE", row: 17)
            return
        }

        writeCentered("7-LETTER BINGOS:", row: 16)

        // Show all bingos, marking found ones
        var allBingoDisplays: [String] = []
        for word in bingoWords.sorted() {
            if foundBingos.contains(word) {
                allBingoDisplays.append(word)  // Found
            } else {
                allBingoDisplays.append(word.lowercased())  // Not found (lowercase)
            }
        }

        let foundCount = foundBingos.count
        let totalCount = bingoWords.count

        // Display bingos across lines 17-19 (3 lines, 3 per line = 9 max visible)
        let bingosPerLine = 3
        let maxLines = 3
        let maxVisible = bingosPerLine * maxLines  // 9

        if totalCount <= maxVisible {
            // Show all bingos if they fit
            var lineNum = 17
            var currentLine: [String] = []

            for bingo in allBingoDisplays {
                currentLine.append(bingo)
                if currentLine.count >= bingosPerLine {
                    writeCentered(currentLine.joined(separator: "  "), row: lineNum)
                    lineNum += 1
                    currentLine = []
                }
            }

            if !currentLine.isEmpty {
                writeCentered(currentLine.joined(separator: "  "), row: lineNum)
            }
        } else {
            // Show subset with scrolling and "+X MORE" indicator
            let startIdx = bingoScrollOffset
            let displayCount = maxVisible - 1  // Leave room for "+X MORE"
            let endIdx = min(startIdx + displayCount, totalCount)
            let visibleBingos = Array(allBingoDisplays[startIdx..<endIdx])

            var lineNum = 17
            var currentLine: [String] = []

            for bingo in visibleBingos {
                currentLine.append(bingo)
                if currentLine.count >= bingosPerLine {
                    writeCentered(currentLine.joined(separator: "  "), row: lineNum)
                    lineNum += 1
                    currentLine = []
                }
            }

            // Add "+X MORE" indicator
            let remaining = totalCount - endIdx
            if remaining > 0 {
                currentLine.append("+\(remaining) MORE")
            }

            if !currentLine.isEmpty && lineNum <= 19 {
                writeCentered(currentLine.joined(separator: "  "), row: lineNum)
            }
        }

        // Show count on line 20
        if totalCount > 1 {
            writeCentered("(\(foundCount)/\(totalCount) FOUND)", row: 20)
        }
    }

    private func getMaxWordCount() -> Int {
        var counts = [0, 0, 0, 0]  // 3, 4, 5, 6 letter words
        for (_, length) in allValidWords {
            switch length {
            case 3: counts[0] += 1
            case 4: counts[1] += 1
            case 5: counts[2] += 1
            case 6: counts[3] += 1
            default: break
            }
        }
        return counts.max() ?? 0
    }

    private func hasMoreWordsToShow() -> Bool {
        return (revealScrollOffset + 8) < getMaxWordCount()
    }

    private func hasMoreGameWordsToShow() -> Bool {
        return (gameScrollOffset + 8) < getMaxWordCount()
    }

    private func renderWordMatrix() {
        // Separate words by length
        var words3: [String] = []
        var words4: [String] = []
        var words5: [String] = []
        var words6: [String] = []

        for (word, length) in allValidWords {
            if length == 7 { continue }
            switch length {
            case 3: words3.append(word)
            case 4: words4.append(word)
            case 5: words5.append(word)
            case 6: words6.append(word)
            default: break
            }
        }

        // Sort each column: found words first (sorted), then unfound as dots
        func sortedDisplay(_ words: [String], dotCount: Int) -> [String] {
            let found = words.filter { foundWords.contains($0) }.sorted()
            let unfoundCount = words.count - found.count
            var result = found
            for _ in 0..<unfoundCount {
                result.append(String(repeating: ".", count: dotCount))
            }
            return result
        }

        let display3 = sortedDisplay(words3, dotCount: 3)
        let display4 = sortedDisplay(words4, dotCount: 4)
        let display5 = sortedDisplay(words5, dotCount: 5)
        let display6 = sortedDisplay(words6, dotCount: 6)

        let maxRows = 8
        let offset = gameScrollOffset

        // Calculate how many more items are below visible area for each column
        func remainingBelow(_ displayList: [String]) -> Int {
            let lastVisibleIdx = offset + maxRows - 1
            if displayList.count > lastVisibleIdx + 1 {
                return displayList.count - lastVisibleIdx - 1
            }
            return 0
        }

        let remaining3 = remainingBelow(display3)
        let remaining4 = remainingBelow(display4)
        let remaining5 = remainingBelow(display5)
        let remaining6 = remainingBelow(display6)

        for i in 0..<maxRows {
            var line = " "
            let idx = i + offset
            let isLastRow = (i == maxRows - 1)

            // 3-letter column (width 10)
            if isLastRow && remaining3 > 0 {
                line += "+\(remaining3) MORE".padding(toLength: 10, withPad: " ", startingAt: 0)
            } else if idx < display3.count {
                line += display3[idx].padding(toLength: 10, withPad: " ", startingAt: 0)
            } else {
                line += String(repeating: " ", count: 10)
            }

            // 4-letter column (width 10)
            if isLastRow && remaining4 > 0 {
                line += "+\(remaining4) MORE".padding(toLength: 10, withPad: " ", startingAt: 0)
            } else if idx < display4.count {
                line += display4[idx].padding(toLength: 10, withPad: " ", startingAt: 0)
            } else {
                line += String(repeating: " ", count: 10)
            }

            // 5-letter column (width 10)
            if isLastRow && remaining5 > 0 {
                line += "+\(remaining5) MORE".padding(toLength: 10, withPad: " ", startingAt: 0)
            } else if idx < display5.count {
                line += display5[idx].padding(toLength: 10, withPad: " ", startingAt: 0)
            } else {
                line += String(repeating: " ", count: 10)
            }

            // 6-letter column (width 9)
            if isLastRow && remaining6 > 0 {
                line += "+\(remaining6) MORE"
            } else if idx < display6.count {
                line += display6[idx]
            }

            writeString(line, row: 7 + i, col: 0)
        }
    }

    private func renderBingoArea() {
        // Show all possible 7-letter bingos
        if bingoWords.isEmpty {
            writeCentered("7-LETTER BINGO: (NONE)", row: 16)
            return
        }

        if bingoWords.count == 1 {
            // Single bingo - original format
            let word = bingoWords[0]
            let display = foundBingos.contains(word)
                ? word.map { String($0) }.joined(separator: " ")
                : "_ _ _ _ _ _ _"
            writeCentered("BINGO: " + display, row: 16)
        } else {
            // Multiple bingos - show count and status with horizontal scrolling
            let foundCount = foundBingos.count
            let totalCount = bingoWords.count
            let sortedBingos = bingoWords.sorted()

            // Build display strings for all bingos
            var allDisplays: [String] = []
            for word in sortedBingos {
                if foundBingos.contains(word) {
                    allDisplays.append(word)
                } else {
                    allDisplays.append("_______")
                }
            }

            // Determine visible bingos based on scroll offset
            let maxVisible = 4  // Leave room for "+X MORE" if needed
            var visibleDisplays: [String] = []

            if totalCount <= 5 {
                // Show all bingos if 5 or fewer
                visibleDisplays = allDisplays
            } else {
                // Show subset with "+X MORE" indicator
                let startIdx = bingoScrollOffset
                let endIdx = min(startIdx + maxVisible, totalCount)
                visibleDisplays = Array(allDisplays[startIdx..<endIdx])

                // Add "+X MORE" if there are more bingos after visible range
                let remaining = totalCount - endIdx
                if remaining > 0 {
                    visibleDisplays.append("+\(remaining) MORE")
                }
            }

            // Show on line 15-16
            writeCentered("BINGOS (\(foundCount)/\(totalCount)):", row: 15)
            let bingoLine = visibleDisplays.joined(separator: " ")
            writeCentered(bingoLine, row: 16)
        }
    }

    // MARK: - Game Logic

    func startNewGame() {
        stopTimer()
        #if DEBUG
        isStressTestMode = false
        #endif
        score = 0
        level = 1
        gameMode = .playing
        startNewRound()
    }

    func startNewRound() {
        stopTimer()

        guard let word = lexicon.getRandomSevenLetterWord() else {
            statusMessage = "* NO 7-LETTER WORDS FOUND *"
            refreshGameDisplay()
            return
        }

        pool = Array(word)
        pool.shuffle()
        poolDisplay = pool  // Start with all letters visible
        userInput = ""
        roundScore = 0
        foundWords.removeAll()
        foundBingos.removeAll()
        allValidWords = lexicon.findAllAnagrams(from: pool)
        gameScrollOffset = 0
        bingoScrollOffset = 0

        // Find all 7-letter bingos for this pool (uses precomputed anagram groups)
        bingoWords = lexicon.getSevenLetterAnagrams(for: pool).sorted()

        timeLeft = 120
        statusMessage = ""
        gameMode = .playing

        refreshGameDisplay()
        startTimer()
    }

    func handleEscape() {
        // First check if debug help is showing
        #if DEBUG
        if dismissDebugHelp() {
            return
        }
        #endif

        switch gameMode {
        case .titleScreen:
            // Do nothing - use CMD-Q to quit from title screen
            break
        case .playing:
            // End the round, show reveal screen (also dismiss any flash screens)
            if isShowingBingoFlash {
                isShowingBingoFlash = false
                savedBuffer = nil
            }
            if isShowingWowFlash {
                isShowingWowFlash = false
                savedBuffer = nil
            }
            showRevealScreen()
        case .revealing:
            // End the game, go to high score or title
            endGame()
        case .gameOver:
            showTitleScreen()
        case .highScoreEntry:
            // Can't escape from high score entry - must enter initials
            break
        case .highScoreList:
            if cameFromRevealScreen {
                // End the game from high scores mid-game
                endGame()
            } else {
                showTitleScreen()
            }
        }
    }

    private func showRevealScreen() {
        stopTimer()
        gameMode = .revealing
        revealScrollOffset = 0
        bingoScrollOffset = 0
        refreshRevealDisplay()
    }

    private func endGame() {
        #if DEBUG
        // Skip high score handling in stress test mode
        if isStressTestMode {
            isStressTestMode = false
            showTitleScreen()
            return
        }
        #endif

        if isHighScore(score) {
            gameMode = .highScoreEntry
            highScoreInitials = ""
            showHighScoreEntryScreen()
        } else {
            // Always show high scores at end of game
            showHighScoreList()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard gameMode == .playing else { return }

        timeLeft -= 1

        if timeLeft <= 0 {
            // Show reveal screen when time runs out
            showRevealScreen()
        } else {
            refreshGameDisplay()
        }
    }

    private func showHighScoreEntryScreen() {
        clearBuffer()
        writeString(String(repeating: "+", count: 40), row: 0, col: 0)
        writeCentered("NEW HIGH SCORE!", row: 1)
        writeString(String(repeating: "+", count: 40), row: 2, col: 0)

        writeCentered(String(format: "SCORE: %06d", score), row: 5)
        writeCentered(String(format: "ROUND: %02d", level), row: 7)

        writeString(String(repeating: "-", count: 40), row: 10, col: 0)
        writeCentered("ENTER YOUR INITIALS:", row: 12)

        // Show initials being entered
        let display = highScoreInitials.padding(toLength: 3, withPad: "_", startingAt: 0)
        writeCentered("[ \(display.map { String($0) }.joined(separator: " ")) ]", row: 14)

        writeString(String(repeating: "-", count: 40), row: 17, col: 0)
        writeCentered("[A-Z] ENTER INITIALS", row: 19)
        writeCentered("[BACKSPACE] DELETE", row: 20)
        writeCentered("[ENTER] CONFIRM", row: 21)
    }

    func showHighScoreList(fromReveal: Bool = false) {
        cameFromRevealScreen = fromReveal
        gameMode = .highScoreList
        clearBuffer()
        writeString(String(repeating: "+", count: 40), row: 0, col: 0)
        writeCentered("HIGH SCORES", row: 1)
        writeString(String(repeating: "+", count: 40), row: 2, col: 0)

        writeString(" ##   NAME     SCORE    ROUND", row: 4, col: 3)
        writeString(String(repeating: "-", count: 34), row: 5, col: 3)

        for i in 0..<min(10, highScores.count) {
            let entry = highScores[i]
            // Pad initials to 3 characters for alignment
            let paddedInitials = entry.initials.padding(toLength: 3, withPad: " ", startingAt: 0)
            let line = String(format: " %2d.  %@     %06d     %02d", i + 1, paddedInitials, entry.score, entry.round)
            writeString(line, row: 6 + i, col: 3)
        }

        if highScores.isEmpty {
            writeCentered("NO HIGH SCORES YET", row: 10)
        }

        writeString(String(repeating: "-", count: 40), row: 18, col: 0)
        if cameFromRevealScreen {
            writeCentered("[ENTER] BACK   [ESC] END GAME", row: 20)
        } else {
            writeCentered("[ENTER] BACK TO TITLE", row: 20)
        }
    }

    private func nextLevel() {
        level += 1
        startNewRound()
    }

    // MARK: - Input Handling

    func handleKeyPress(_ key: String) {
        // Title screen - Enter to start, H for high scores
        if gameMode == .titleScreen {
            if key == "\r" {
                startNewGame()
            } else if key.uppercased() == "H" {
                showHighScoreList()
            }
            return
        }

        // High score list - Enter to go back (to reveal or title)
        if gameMode == .highScoreList {
            if key == "\r" {
                if cameFromRevealScreen {
                    gameMode = .revealing
                    refreshRevealDisplay()
                } else {
                    showTitleScreen()
                }
            }
            return
        }

        // High score entry - type initials
        if gameMode == .highScoreEntry {
            if key == "\r" {
                // Confirm initials
                if highScoreInitials.isEmpty {
                    highScoreInitials = "AAA"
                }
                addHighScore(initials: highScoreInitials, score: score, round: level)
                showHighScoreList()
            } else if key == "\u{7F}" || key == "\u{08}" {
                // Backspace
                if !highScoreInitials.isEmpty {
                    highScoreInitials.removeLast()
                    showHighScoreEntryScreen()
                }
            } else if key.count == 1, let char = key.uppercased().first, char.isLetter {
                if highScoreInitials.count < 3 {
                    highScoreInitials.append(char)
                    showHighScoreEntryScreen()
                }
            }
            return
        }

        // Game over - Enter to go back to title, D for definitions
        if gameMode == .gameOver {
            if key == "\r" {
                showTitleScreen()
            } else if key.uppercased() == "D" {
                showDefinitionsWindow()
            }
            return
        }

        // Reveal screen - Enter to continue (if enough points), D for definitions, H for high scores
        if gameMode == .revealing {
            if key == "\r" && roundScore >= minScoreRequired && !isStressTestMode {
                // Continue to next round only if scored enough (and not in stress test mode)
                nextLevel()
            } else if key.uppercased() == "D" {
                showDefinitionsWindow()
            } else if key.uppercased() == "H" {
                showHighScoreList(fromReveal: true)
            }
            // ESC is handled separately in handleEscape()
            return
        }

        // Playing - but first check if flash screens are showing
        if isShowingBingoFlash {
            // Ignore all keys during BINGO flash
            return
        }

        if isShowingWowFlash {
            if key == "\r" {
                dismissWowScreen()
            }
            // Ignore all other keys while WOW is showing
            return
        }

        if key == " " {
            pool.shuffle()
            updatePoolDisplay()
            statusMessage = ""
            refreshGameDisplay()
        } else if key == "\r" {
            submitWord()
        } else if key == "\u{7F}" || key == "\u{08}" {
            if !userInput.isEmpty {
                userInput.removeLast()
                updatePoolDisplay()
                statusMessage = ""
                refreshGameDisplay()
            }
        } else if key.count == 1, let char = key.uppercased().first, char.isLetter {
            // Only allow typing if letter is available in pool (or in stress test mode)
            if userInput.count < 7 && (isStressTestMode || poolDisplay.contains(char)) {
                userInput.append(char)
                if !isStressTestMode {
                    updatePoolDisplay()
                }
                statusMessage = ""
                refreshGameDisplay()
            }
        }
    }

    private func updatePoolDisplay() {
        // Start with full pool, replace typed letters with spaces (preserving positions)
        var available = pool
        for char in userInput {
            if let idx = available.firstIndex(of: char) {
                available[idx] = " "  // Replace with space, don't remove
            }
        }
        poolDisplay = available
    }

    private func showDefinitionsWindow() {
        if isStressTestMode {
            // Show blank definitions window in stress test mode
            definitionsWindowController.show(
                words: [:],
                foundWords: [],
                lexicon: lexicon
            )
            return
        }

        definitionsWindowController.show(
            words: allValidWords,
            foundWords: foundWords,
            lexicon: lexicon
        )
    }

    func closeDefinitionsWindow() -> Bool {
        return definitionsWindowController.closeIfOpen()
    }

    func handleArrowKey(isUp: Bool) {
        if gameMode == .playing {
            if isUp {
                if gameScrollOffset > 0 {
                    gameScrollOffset -= 1
                    refreshGameDisplay()
                }
            } else {
                if hasMoreGameWordsToShow() {
                    gameScrollOffset += 1
                    refreshGameDisplay()
                }
            }
        } else if gameMode == .revealing {
            if isUp {
                if revealScrollOffset > 0 {
                    revealScrollOffset -= 1
                    refreshRevealDisplay()
                }
            } else {
                if hasMoreWordsToShow() {
                    revealScrollOffset += 1
                    refreshRevealDisplay()
                }
            }
        }
    }

    func handleHorizontalArrowKey(isLeft: Bool) {
        // Only handle if there are enough bingos to scroll
        // Gameplay: >5 bingos, Reveal: >9 bingos
        let maxVisibleGameplay = 5
        let maxVisibleReveal = 9

        if gameMode == .playing {
            guard bingoWords.count > maxVisibleGameplay else { return }
            let maxOffset = max(0, bingoWords.count - 4)  // Show 4 bingos + "+X MORE"

            if isLeft {
                if bingoScrollOffset > 0 {
                    bingoScrollOffset -= 1
                    refreshGameDisplay()
                }
            } else {
                if bingoScrollOffset < maxOffset {
                    bingoScrollOffset += 1
                    refreshGameDisplay()
                }
            }
        } else if gameMode == .revealing {
            guard bingoWords.count > maxVisibleReveal else { return }
            let maxOffset = max(0, bingoWords.count - 8)  // Show 8 bingos + "+X MORE"

            if isLeft {
                if bingoScrollOffset > 0 {
                    bingoScrollOffset -= 1
                    refreshRevealDisplay()
                }
            } else {
                if bingoScrollOffset < maxOffset {
                    bingoScrollOffset += 1
                    refreshRevealDisplay()
                }
            }
        }
    }

    private func submitWord() {
        let word = userInput.uppercased()
        userInput = ""
        updatePoolDisplay()  // Reset pool display

        guard word.count >= 3 else {
            setStatusMessage("* TOO SHORT *")
            return
        }

        // Stress test mode: every word is valid until slots are filled
        #if DEBUG
        if isStressTestMode {
            submitStressTestWord(word)
            return
        }
        #endif

        guard canFormWord(word) else {
            setStatusMessage("* INVALID LETTERS *")
            return
        }

        guard lexicon.isValidWord(word) else {
            setStatusMessage("* NOT IN LIST *")
            return
        }

        guard !foundWords.contains(word) else {
            setStatusMessage("* DUPLICATE WORD *")
            return
        }

        // Valid word!
        foundWords.insert(word)
        let points = scoreForWord(length: word.count)
        score += points
        roundScore += points
        var message = "* \"\(word)\" +\(points) PTS *"

        // Apply time bonus for 5, 6, and 7 letter words
        switch word.count {
        case 7:
            if bingoWords.contains(word) {
                foundBingos.insert(word)
                if foundBingos.count == bingoWords.count && bingoWords.count > 1 {
                    message = "* ALL BINGOS! \"\(word)\" +\(points) PTS *"
                } else {
                    message = "* BINGO! \"\(word)\" +\(points) PTS *"
                }
                // Flash BINGO! overlay
                triggerBingoFlash()
            }
            // +21 seconds (accounts for 1s bingo display), shown as +20
            applyTimeBonus(seconds: 21, displayAs: "+20")
        case 6:
            applyTimeBonus(seconds: 10, displayAs: "+10")
        case 5:
            applyTimeBonus(seconds: 5, displayAs: "+5")
        default:
            break
        }

        setStatusMessage(message)

        // Check if all words found
        if foundWords.count == allValidWords.count {
            stopTimer()  // Stop timer immediately
            showWowScreen()  // Show WOW screen, wait for ENTER to continue
        }
    }

    #if DEBUG
    private func submitStressTestWord(_ word: String) {
        let length = word.count
        guard length >= 3 && length <= 7 else {
            setStatusMessage("* INVALID LENGTH *")
            return
        }

        // Check if there are slots remaining for this word length
        let maxSlots: [Int: Int] = [3: 500, 4: 400, 5: 300, 6: 200, 7: 100]
        let currentCount = stressTestWordCounts[length] ?? 0
        let maxCount = maxSlots[length] ?? 0

        guard currentCount < maxCount else {
            setStatusMessage("* NO MORE \(length)-LETTER SLOTS *")
            return
        }

        // Generate the next dummy word for this length and mark it found
        let dummyWord = generateStressTestDummyWord(length: length, index: currentCount)
        foundWords.insert(dummyWord)
        stressTestWordCounts[length] = currentCount + 1

        // Handle bingos
        if length == 7 {
            foundBingos.insert(dummyWord)
            triggerBingoFlash()
        }

        // Award points and time bonus
        let points = scoreForWord(length: length)
        score += points
        roundScore += points

        var message = "* \"\(word)\" +\(points) PTS *"

        switch length {
        case 7:
            message = "* BINGO! \"\(word)\" +\(points) PTS *"
            applyTimeBonus(seconds: 21, displayAs: "+20")
        case 6:
            applyTimeBonus(seconds: 10, displayAs: "+10")
        case 5:
            applyTimeBonus(seconds: 5, displayAs: "+5")
        default:
            break
        }

        setStatusMessage(message)

        // Check if all words found
        if foundWords.count == allValidWords.count {
            stopTimer()
            showWowScreen()
        }
    }

    private func generateStressTestDummyWord(length: Int, index: Int) -> String {
        // Generate dummy words matching the pattern used in debugStartStressTest
        switch length {
        case 3:
            let prefixChar = Character(UnicodeScalar(65 + (index / 100))!)  // A, B, C, D, E
            return "\(prefixChar)\(String(format: "%02d", index % 100))"
        case 4:
            let prefixChar = Character(UnicodeScalar(65 + (index / 100))!)  // A, B, C, D
            return "A\(prefixChar)\(String(format: "%02d", index % 100))"
        case 5:
            let prefixChar = Character(UnicodeScalar(65 + (index / 100))!)  // A, B, C
            return "AA\(prefixChar)\(String(format: "%02d", index % 100))"
        case 6:
            let prefixChar = Character(UnicodeScalar(65 + (index / 100))!)  // A, B
            return "AAA\(prefixChar)\(String(format: "%02d", index % 100))"
        case 7:
            return "AAAA\(String(format: "%03d", index))"
        default:
            return ""
        }
    }
    #endif

    private func canFormWord(_ word: String) -> Bool {
        var available = Dictionary(grouping: pool) { $0 }.mapValues { $0.count }

        for char in word {
            if let count = available[char], count > 0 {
                available[char] = count - 1
            } else {
                return false
            }
        }
        return true
    }

    private func scoreForWord(length: Int) -> Int {
        switch length {
        case 3: return 50
        case 4: return 75
        case 5: return 100
        case 6: return 200
        case 7: return 300
        default: return 0
        }
    }

    private func triggerBingoFlash() {
        // Save current buffer (deep copy)
        savedBuffer = buffer.map { $0 }
        isShowingBingoFlash = true

        // Render BINGO to buffer
        clearBuffer()

        // Add edge content so barrel distortion is visible
        // (distortion is minimal at center, maximal at edges)
        writeString(String(repeating: "+", count: 40), row: 0, col: 0)
        writeString(String(repeating: "+", count: 40), row: 23, col: 0)

        let bingoArt = [
            "###   ###  #   #   ###    ###   #",
            "#  #   #   ##  #  #      #   #  #",
            "###    #   # # #  #  ##  #   #  #",
            "#  #   #   #  ##  #   #  #   #   ",
            "###   ###  #   #   ###    ###   #"
        ]
        let startRow = 9  // Center vertically
        for (index, line) in bingoArt.enumerated() {
            writeCentered(line, row: startRow + index)
        }

        // Force view update after all writes
        objectWillChange.send()

        // Restore after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.isShowingBingoFlash else { return }
            self.isShowingBingoFlash = false
            if let saved = self.savedBuffer {
                self.buffer = saved.map { $0 }
                self.savedBuffer = nil
                self.objectWillChange.send()
            }
        }
    }

    private func showWowScreen() {
        // Save current buffer (deep copy) and show WOW screen
        savedBuffer = buffer.map { $0 }
        isShowingWowFlash = true

        clearBuffer()

        // Add edge content so barrel distortion is visible
        // (distortion is minimal at center, maximal at edges)
        writeString(String(repeating: "+", count: 40), row: 0, col: 0)
        writeString(String(repeating: "+", count: 40), row: 23, col: 0)

        let wowArt = [
            "#   #   ###   #   #",
            "#   #  #   #  #   #",
            "# # #  #   #  # # #",
            "## ##  #   #  ## ##",
            "#   #   ###   #   #"
        ]
        let startRow = 8  // Center vertically
        for (index, line) in wowArt.enumerated() {
            writeCentered(line, row: startRow + index)
        }
        writeCentered("YOU FOUND EVERY WORD!", row: 15)
        writeCentered("[ENTER] CONTINUE", row: 17)

        // Force view update after all writes
        objectWillChange.send()
    }

    private func dismissWowScreen() {
        isShowingWowFlash = false
        savedBuffer = nil  // Don't restore - we're going to reveal screen
        showRevealScreen()
    }

    private func applyTimeBonus(seconds: Int, displayAs: String) {
        timeLeft += seconds
        timeBonusDisplay = displayAs
        refreshGameDisplay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.timeBonusDisplay = nil
            self?.refreshGameDisplay()
        }
    }

    private func setStatusMessage(_ message: String, clearAfter seconds: Double = 2.0) {
        statusMessage = message
        refreshGameDisplay()
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self = self else { return }
            // Only clear if it's still the same message (avoid clearing newer messages)
            if self.statusMessage == message {
                self.statusMessage = ""
                self.refreshGameDisplay()
            }
        }
    }
}
