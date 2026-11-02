import Foundation
import AppKit
import Combine

enum GameMode {
    case titleScreen
    case playing
    case paused
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

@MainActor
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

    let soundEffects: SoundEffects
    let defaults: UserDefaults
    var drawingBuffer = Array(repeating: Array(repeating: Character(" "), count: bufferCols), count: bufferRows)
    var roundID = UUID()
    var statusID = UUID()
    var bonusID = UUID()
    var flashID = UUID()
    var loadError: String?

    var canAdvance: Bool {
        !isStressTestMode && (roundScore >= minScoreRequired ||
            (!allValidWords.isEmpty && foundWords.count == allValidWords.count))
    }

    func invalidateTransientDisplays() {
        roundID = UUID()
        statusID = UUID()
        bonusID = UUID()
        flashID = UUID()
        flashOverlay = .none
        timeBonusDisplay = nil
        statusMessage = ""
    }

    // Flash screen state (BINGO/WOW/debug help rendered to buffer)
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
    @Published var highScores: [HighScoreEntry] = []  // High score list
    #if DEBUG
    var isStressTestMode: Bool = false  // Flag for stress test display mode
    #else
    let isStressTestMode: Bool = false  // Always false in release builds
    #endif
    var highScoreInitials: String = ""  // Initials being entered for high score
    var isPaused: Bool { gameMode == .paused }
    var hintUsed: Bool = false  // Whether bingo hint has been used this round
    var hintBingoWord: String? = nil  // The bingo word being hinted
    var hintRevealedPositions: Set<Int> = []  // Which letter positions are revealed
    var cameFromRevealScreen: Bool = false  // Track if high scores accessed mid-game
    #if DEBUG
    var stressTestWordCounts: [Int: Int] = [:]  // Track submitted words per length in stress test
    #endif

    var lexicon: Lexicon
    private let highScoresKey = "PlaintextPanicHighScores"
    private let wordListKey = "PlaintextPanicWordList"
    private let letterColorKey = "PlaintextPanicLetterColor"
    var minScoreRequired: Int { min(400 + (level - 1) * 25, 525) }  // 400 at round 1, 450 at round 3, caps at 525
    private let maxHighScores = 10
    private var timer: Timer?
    private var cursorTimer: Timer?
    var definitionsWindowController = DefinitionsWindowController()

    init(defaults: UserDefaults = .standard, lexicon: Lexicon = Lexicon(), blinkCursor: Bool = true) {
        self.defaults = defaults
        self.lexicon = lexicon
        self.soundEffects = SoundEffects(defaults: defaults)
        // Load word list preference
        if let savedList = defaults.string(forKey: wordListKey),
           let listType = WordListType(rawValue: savedList) {
            currentWordList = listType
        }
        // Load letter color preference
        if let savedColor = defaults.string(forKey: letterColorKey),
           let colorType = LetterColor(rawValue: savedColor) {
            letterColor = colorType
        }
        isSoundEnabled = soundEffects.soundEnabled
        if !lexicon.load(wordList: currentWordList) {
            loadError = "WORD LIST UNAVAILABLE - TRY SETTINGS"
        }
        loadHighScores()
        if blinkCursor { startCursorBlink() }
        showTitleScreen()
    }

    private func startCursorBlink() {
        cursorTimer?.invalidate()
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.gameMode == .playing, self.flashOverlay == .none else { return }
                self.cursorVisible.toggle()
                self.refreshGameDisplay()
            }
        }
    }

    // MARK: - High Scores

    private func loadHighScores() {
        if let data = defaults.data(forKey: highScoresKey),
           let scores = try? JSONDecoder().decode([HighScoreEntry].self, from: data) {
            highScores = scores
        }
    }

    private func saveHighScores() {
        if let data = try? JSONEncoder().encode(highScores) {
            defaults.set(data, forKey: highScoresKey)
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
        if gameMode == .highScoreList {
            showHighScoreList(fromReveal: cameFromRevealScreen)
        }
    }

    // MARK: - Word List Management

    func switchWordList(to listType: WordListType) {
        guard gameMode == .titleScreen else { return }  // Only allow switching from title screen
        guard lexicon.switchWordList(to: listType) else {
            loadError = "WORD LIST UNAVAILABLE - TRY SETTINGS"
            showTitleScreen()
            return
        }
        currentWordList = listType
        loadError = nil
        defaults.set(listType.rawValue, forKey: wordListKey)
        showTitleScreen()  // Refresh to show any changes
    }

    func switchLetterColor(to color: LetterColor) {
        letterColor = color
        defaults.set(color.rawValue, forKey: letterColorKey)
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
        defer { publishBuffer() }

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
        invalidateTransientDisplays()
        hintUsed = false
        hintBingoWord = nil
        hintRevealedPositions.removeAll()
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
        let previousRoundScore = roundScore
        roundScore = totalPoints
        score += totalPoints - previousRoundScore

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
        applyTimeBonus(seconds: 21, displayAs: "+20")

        // Show bingo flash and fanfare
        soundEffects.playBingoFanfare()
        triggerBingoFlash()

        statusMessage = "* BINGO! \"\(bingo)\" +\(points) PTS *"
        refreshGameDisplay()

        setStatusMessage(statusMessage)
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
        invalidateTransientDisplays()

        guard let word = lexicon.getRandomSevenLetterWord() else {
            loadError = "WORD LIST UNAVAILABLE - TRY SETTINGS"
            showTitleScreen()
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
            if flashOverlay == .wow {
                dismissWowScreen()
                return
            }
            // Dismiss flash screens if showing
            if flashOverlay != .none {
                flashOverlay = .none
            }
            // First ESC pauses the game
            gameMode = .paused
            showPausedScreen()
        case .paused:
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

    func showRevealScreen() {
        stopTimer()
        invalidateTransientDisplays()
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
        let activeRound = roundID
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.roundID == activeRound else { return }
                self.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopTimer() {
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
