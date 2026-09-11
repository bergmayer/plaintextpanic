import AppKit
import Combine
import Foundation

@main
struct Regression {
    @MainActor static func main() async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let suite = "PlaintextPanicRegression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(false, forKey: "PlaintextPanicSoundEnabled")
        defer { defaults.removePersistentDomain(forName: suite) }
        func engine() -> GameEngine { GameEngine(defaults: defaults, blinkCursor: false) }
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
        }
        func row(_ engine: GameEngine, _ index: Int) -> String { String(engine.buffer[index]) }
        func centered(_ text: String) -> String {
            let left = max(0, (40 - text.count) / 2)
            return String(repeating: " ", count: left) + text + String(repeating: " ", count: max(0, 40-left-text.count))
        }
        func grid(_ engine: GameEngine) {
            check(engine.buffer.count == 24 && engine.buffer.allSatisfy { $0.count == 40 }, "Every screen must remain 24 x 40")
        }
        func round(_ engine: GameEngine, word: String = "AEINRST") {
            engine.startNewGame()
            engine.stopTimer()
            engine.pool = Array(word)
            engine.poolDisplay = engine.pool
            engine.allValidWords = engine.lexicon.findAllAnagrams(from: engine.pool)
            engine.bingoWords = engine.lexicon.getSevenLetterAnagrams(for: engine.pool).sorted()
            engine.refreshGameDisplay()
        }

        let game = engine()
        check(game.lexicon.wordCount == 56987, "Full dictionary loads")
        check(row(game, 8) == centered("MEET TARGET OR FIND EVERY WORD!"), "Title explains advancement within 40 columns")
        grid(game)
        round(game)
        check(row(game, 19) == centered("A   E   I   N   R   S   T"), "Pool stays on row 19")
        check(row(game, 23) == centered("[SPC]SHUFFLE [TAB]HINT [ESC]PAUSE"), "Controls fit the footer")
        check(String(game.buffer[3][1..<12]) == "PTS:000/400", "Score field stays in its column")
        check(String(game.buffer[3][16..<24]) == "ROUND:01", "Round field stays centered")
        check(String(game.buffer[3][31..<39]) == "TIME:120", "Time field stays right aligned")
        var publications = 0
        let frames = game.$buffer.dropFirst().sink { _ in publications += 1 }
        game.userInput = "A"
        game.refreshGameDisplay()
        check(publications == 1, "One completed frame is published per changed screen")
        game.refreshGameDisplay()
        check(publications == 1, "Identical frames need no publication")
        withExtendedLifetime(frames) {}

        // All four fixed columns show seven words plus a truthful overflow count.
        game.allValidWords = [:]
        for length in 3...6 {
            for index in 0..<9 {
                let word = String(repeating: "A", count: length-1) + String(UnicodeScalar(65+index)!)
                game.allValidWords[word] = length
            }
        }
        game.showRevealScreen()
        check(row(game, 14) == " " + String(repeating: "+2 MORE   ", count: 3) + "+2 MORE  ", "Overflow indicator occupies the eighth row")
        game.handleArrowKey(isUp: false)
        for col in [1,11,21,31] { check(game.buffer[14][col] == ".", "Last word becomes visible on scroll") }
        check(!game.hasMoreWordsToShow(), "Scroll ends only after all words are visible")
        grid(game)

        // Check bingo capacity boundaries, both layouts, and reachability of every item.
        for count in [1, 5, 6, 9, 10, 100] {
            game.bingoWords = (0..<count).map { String(format: "B%06d", $0) }
            game.foundBingos = Set(game.bingoWords)
            game.gameMode = .playing
            game.bingoScrollOffset = 0
            game.refreshGameDisplay()
            var seen: Set<String> = []
            for _ in 0...count {
                grid(game)
                let screen = row(game, 16)
                seen.formUnion(game.bingoWords.filter { screen.contains($0) || screen.contains($0.map(String.init).joined(separator: " ")) })
                game.handleHorizontalArrowKey(isLeft: false)
            }
            check(seen.count == count, "Every gameplay bingo is reachable: \(count)")
            game.showRevealScreen()
            seen = []
            for _ in 0...count {
                grid(game)
                let screen = (17...19).map { row(game, $0) }.joined(separator: "\n")
                seen.formUnion(game.bingoWords.filter { screen.contains($0) })
                game.handleHorizontalArrowKey(isLeft: false)
            }
            check(seen.count == count, "Every revealed bingo is reachable: \(count)")
        }

        // Delayed display work must not change the pause/reveal/title/initials screens.
        let paused = engine(); round(paused)
        paused.setStatusMessage("PENDING", clearAfter: 0.01)
        paused.handleEscape()
        let pauseFrame = paused.buffer
        let revealed = engine(); round(revealed)
        revealed.applyTimeBonus(seconds: 5, displayAs: "+5")
        revealed.showRevealScreen()
        let revealFrame = revealed.buffer
        let titled = engine(); round(titled)
        titled.applyTimeBonus(seconds: 5, displayAs: "+5")
        titled.showTitleScreen()
        let titleFrame = titled.buffer
        let initials = engine(); round(initials)
        initials.applyTimeBonus(seconds: 5, displayAs: "+5")
        initials.showRevealScreen()
        initials.score = 123
        initials.highScores = []
        initials.handleEscape()
        let initialsFrame = initials.buffer
        let repeated = engine(); round(repeated)
        repeated.setStatusMessage("SAME", clearAfter: 0.01)
        repeated.setStatusMessage("SAME", clearAfter: 1)
        try await Task.sleep(nanoseconds: 50_000_000)
        check(repeated.statusMessage == "SAME", "Old callback cannot clear a repeated message")
        check(paused.buffer == pauseFrame && paused.isPaused, "Paused letters remain concealed")
        try await Task.sleep(nanoseconds: 2_100_000_000)
        check(revealed.buffer == revealFrame, "Bonus callback cannot overwrite reveal")
        check(titled.buffer == titleFrame, "Bonus callback cannot overwrite title")
        check(initials.buffer == initialsFrame, "Bonus callback cannot overwrite initials entry")

        // Earlier bonuses must not shorten newer bonuses in the same or a new round.
        let overlapping = engine(); round(overlapping)
        let nextRound = engine(); round(nextRound)
        overlapping.applyTimeBonus(seconds: 5, displayAs: "+5")
        nextRound.applyTimeBonus(seconds: 5, displayAs: "+5")
        try await Task.sleep(nanoseconds: 1_100_000_000)
        overlapping.applyTimeBonus(seconds: 10, displayAs: "+10")
        nextRound.startNewRound(); nextRound.stopTimer()
        nextRound.applyTimeBonus(seconds: 10, displayAs: "+10")
        let bingo = engine(); round(bingo)
        bingo.userInput = "RETAINS"
        bingo.handleKeyPress("\r")
        check(bingo.flashOverlay == .bingo, "Seven-letter submission flashes")
        grid(bingo)
        try await Task.sleep(nanoseconds: 1_100_000_000)
        check(overlapping.timeBonusDisplay == "+10" && nextRound.timeBonusDisplay == "+10", "Old bonus expiry cannot clear newer bonuses")
        check(bingo.flashOverlay == .none && bingo.foundWords.contains("RETAINS"), "Bingo returns to current gameplay")
        check(row(bingo, 15) == centered("BINGOS (1/9):"), "Bingo redraw shows the new count, not a saved old frame")

        // Perfect rounds advance despite a low total, including after hint penalties.
        for list in WordListType.allCases {
            let perfect = engine()
            perfect.switchWordList(to: list)
            for word in (list == .full ? ["VIVIFIC", "UNFUNNY", "EXEGETE"] : ["UNFUNNY", "EXEGETE"]) {
                round(perfect, word: word)
                perfect.level = 6
                perfect.foundWords = Set(perfect.allValidWords.keys)
                perfect.roundScore = perfect.allValidWords.values.reduce(0) { $0 + perfect.scoreForWord(length: $1) }
                perfect.showWowScreen()
                perfect.handleKeyPress("\r")
                check(perfect.canAdvance, "Perfect \(word) round must advance")
                check(row(perfect, 22) == centered("[ENTER] NEXT ROUND   [D] DEFINITIONS"), "Instructions agree with advancement")
                perfect.handleKeyPress("\r")
                check(perfect.level == 7 && perfect.gameMode == .playing, "Enter advances perfect round")
                perfect.stopTimer()
            }
        }
        defaults.set("full", forKey: "PlaintextPanicWordList")
        let vivific = engine(); round(vivific, word: "VIVIFIC")
        vivific.handleHint()
        vivific.userInput = "VIVIFIC"
        vivific.handleKeyPress("\r")
        check(vivific.roundScore == 150 && vivific.flashOverlay == .wow, "Hinted perfect round is recognized")
        vivific.handleEscape()
        check(vivific.gameMode == .revealing && vivific.canAdvance, "Escape from WOW ends the round, never resumes a stopped timer")

        // Native secondary-window events pass through without mutating the game.
        let delegate = AppDelegate()
        let keys = engine(); round(keys)
        delegate.gameEngine = keys
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        func event(_ text: String, _ code: UInt16) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
        }
        for (text, code) in [("\t", UInt16(48)), ("\u{1b}", UInt16(53)), ("a", UInt16(0))] {
            let key = event(text, code)
            check(delegate.handleKeyEvent(key) === key, "Secondary-window input passes through")
        }
        check(!keys.hintUsed && !keys.isPaused && keys.userInput.isEmpty, "Secondary input leaves game intact")
        window.identifier = NSUserInterfaceItemIdentifier("game")
        check(delegate.handleKeyEvent(event("\t", 48)) == nil && keys.hintUsed, "Game window retains its hint shortcut")
        keys.handleEscape()
        check(delegate.handleKeyEvent(event("\t", 48)) == nil && !keys.isPaused, "Tab resumes the paused game as advertised")
        window.close()

        // Reset updates persisted scores, published scores and the terminal frame.
        keys.addHighScore(initials: "ABC", score: 100, round: 1)
        keys.showRevealScreen()
        keys.showHighScoreList(fromReveal: true)
        var publishedScores = -1
        let scores = keys.$highScores.sink { publishedScores = $0.count }
        keys.resetHighScores()
        check(publishedScores == 0, "Observed high-score window receives reset")
        check(row(keys, 10) == centered("NO HIGH SCORES YET"), "Terminal reset redraws")
        check(keys.cameFromRevealScreen, "Reset preserves return destination")
        check(engine().highScores.isEmpty, "Reset persists")
        withExtendedLifetime(scores) {}

        // Failed replacements preserve the loaded dictionary and preference.
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("Lexicon-\(UUID().uuidString).bundle")
        let resources = fixture.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixture) }
        try "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>test.lexicon</string></dict></plist>".write(to: fixture.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)
        try FileManager.default.copyItem(at: Bundle.main.url(forResource: "02_full", withExtension: "gz")!, to: resources.appendingPathComponent("02_full.gz"))
        let lexicon = Lexicon(resourceBundle: Bundle(url: fixture)!)
        let loading = GameEngine(defaults: defaults, lexicon: lexicon, blinkCursor: false)
        loading.switchWordList(to: .full)
        loading.switchWordList(to: .common)
        check(loading.currentWordList == .full && lexicon.currentWordList == .full && lexicon.isValidWord("VIVIFIC"), "Failed switch keeps the previous dictionary")
        check(defaults.string(forKey: "PlaintextPanicWordList") == "full", "Failed switch keeps preference")
        try FileManager.default.removeItem(at: resources.appendingPathComponent("02_full.gz"))
        let unavailable = GameEngine(defaults: defaults, lexicon: Lexicon(resourceBundle: Bundle(url: fixture)!), blinkCursor: false)
        unavailable.startNewGame()
        check(unavailable.gameMode == .titleScreen && unavailable.loadError != nil, "Missing dictionary remains recoverable on title")
        check(row(unavailable, 23) == centered("WORD LIST UNAVAILABLE - TRY SETTINGS"), "Load error fits the footer")
        grid(unavailable)
        #if DEBUG
        print("PASS: Debug regression and 24x40 layout checks")
        #else
        print("PASS: Release regression and 24x40 layout checks")
        #endif
    }
}
