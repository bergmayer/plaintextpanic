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

enum FlashOverlay {
    case none
    case bingo
    case wow
    #if DEBUG
    case debugHelp
    #endif
}

struct HighScoreEntry: Codable {
    var initials: String
    var score: Int
    var round: Int
}

class GameEngine: ObservableObject {
    static let bufferRows = 24
    static let bufferCols = 40

    @Published var buffer: [[Character]] = Array(repeating: Array(repeating: Character(" "), count: bufferCols), count: bufferRows)
    @Published var gameMode: GameMode = .titleScreen
    @Published var cursorVisible: Bool = true  // For blinking cursor
    @Published var timeBonusDisplay: String? = nil  // Shows "+20", "+10", "+5" briefly
    #if DEBUG
    @Published var isDebugMode: Bool = false  // Debug mode - red text, debug commands enabled
    #else
    let isDebugMode: Bool = false  // Always false in release builds
    #endif
    @Published var currentWordList: WordListType = .full  // Current word list selection
    @Published var letterColor: LetterColor = .green  // Letter color preference
    @Published var isSoundEnabled: Bool = true  // Sound effects toggle

    let soundEffects = SoundEffects()

    // Flash screen state (BINGO/WOW/debug help rendered to buffer)
    var savedBuffer: [[Character]]? = nil
    var flashOverlay: FlashOverlay = .none

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
    var isStressTestMode: Bool = false  // Flag for stress test display mode
    #else
    let isStressTestMode: Bool = false  // Always false in release builds
    #endif
    var highScoreInitials: String = ""  // Initials being entered for high score
    var isPaused: Bool = false  // Game paused during play
    var hintUsed: Bool = false  // Whether bingo hint has been used this round
    var hintBingoWord: String? = nil  // The bingo word being hinted
    var hintRevealedPositions: Set<Int> = []  // Which letter positions are revealed
    var cameFromRevealScreen: Bool = false  // Track if high scores accessed mid-game
    #if DEBUG
    var stressTestWordCounts: [Int: Int] = [:]  // Track submitted words per length in stress test
    #endif

    var lexicon = Lexicon()
    private let highScoresKey = "PlaintextPanicHighScores"
    private let wordListKey = "PlaintextPanicWordList"
    private let letterColorKey = "PlaintextPanicLetterColor"
    var minScoreRequired: Int { min(400 + (level - 1) * 25, 525) }  // 400 at round 1, 450 at round 3, caps at 525
    private let maxHighScores = 10
    private var timer: Timer?
    private var cursorTimer: Timer?
    var definitionsWindowController = DefinitionsWindowController()

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
        isSoundEnabled = soundEffects.soundEnabled
        _ = lexicon.load(wordList: currentWordList)
        loadHighScores()
        startCursorBlink()
        showTitleScreen()
    }

    private func startCursorBlink() {
        cursorTimer?.invalidate()
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.cursorVisible.toggle()
            if self?.gameMode == .playing && self?.isPaused != true {
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

    func addHighScore(initials: String, score: Int, round: Int) {
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

    func toggleSound() {
        isSoundEnabled.toggle()
        soundEffects.soundEnabled = isSoundEnabled
    }

    // MARK: - Debug

    #if DEBUG
    /// Toggle debug mode (Ctrl+Cmd+Opt+D from title screen)
    func toggleDebugMode() {
        guard gameMode == .titleScreen || flashOverlay == .debugHelp else { return }

        if flashOverlay == .debugHelp {
            // Dismiss debug help
            flashOverlay = .none
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
        guard flashOverlay == .debugHelp else { return false }
        flashOverlay = .none
        showTitleScreen()
        return true
    }

    private func showDebugHelp() {
        flashOverlay = .debugHelp
        clearBuffer()

        writeString(String(repeating: "+", count: Self.bufferCols), row: 0, col: 0)
        writeCentered("+++ DEBUG MODE ACTIVE +++", row: 1)
        writeString(String(repeating: "+", count: Self.bufferCols), row: 2, col: 0)

        writeCentered("COMMANDS (Ctrl+Cmd+Option+):", row: 5)
        writeString("  D - Toggle debug mode", row: 7, col: 6)
        writeString("  W - Complete round (WOW)", row: 8, col: 6)
        writeString("  B - Find next bingo", row: 9, col: 6)
        writeString("  7 - New round with AEINRST", row: 10, col: 6)
        writeString("  X - Stress test (many words)", row: 11, col: 6)
        writeString("  T - Set timer to 10 seconds", row: 12, col: 6)

        writeString(String(repeating: "-", count: Self.bufferCols), row: 14, col: 0)
        writeCentered("[ESC] DISMISS", row: 16)
    }

    /// Debug function to set timer to 10 seconds (Ctrl+Cmd+Opt+T)
    func debugSetShortTimer() {
        guard isDebugMode else { return }
        guard gameMode == .playing else { return }
        timeLeft = 10
        statusMessage = "* DEBUG: TIMER SET TO 10S *"
        refreshGameDisplay()
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
        guard gameMode == .playing, flashOverlay == .none else { return }

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
        guard gameMode == .playing, flashOverlay == .none else { return }
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

        // Show bingo flash and fanfare
        soundEffects.playBingoFanfare()
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
        isPaused = false
        hintUsed = false
        hintBingoWord = nil
        hintRevealedPositions.removeAll()
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
            // If paused, second ESC ends the round
            if isPaused {
                isPaused = false
                showRevealScreen()
                return
            }
            // Dismiss flash screens if showing
            if flashOverlay != .none {
                flashOverlay = .none
                savedBuffer = nil
            }
            // First ESC pauses the game
            isPaused = true
            showPausedScreen()
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

    func showRevealScreen() {
        stopTimer()
        isPaused = false
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

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard gameMode == .playing, !isPaused else { return }

        timeLeft -= 1

        if timeLeft <= 0 {
            // Show reveal screen when time runs out
            showRevealScreen()
        } else {
            // Countdown beeps for last 5 seconds
            if timeLeft <= 5 {
                soundEffects.playCountdown(secondsLeft: timeLeft)
            }
            refreshGameDisplay()
        }
    }

    func nextLevel() {
        level += 1
        startNewRound()
    }
}
