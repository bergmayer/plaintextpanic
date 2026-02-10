import Foundation

// MARK: - Display Rendering
// All buffer management and screen rendering methods for GameEngine.

extension GameEngine {

    // MARK: - Buffer Management

    func clearBuffer() {
        objectWillChange.send()
        for row in 0..<Self.bufferRows {
            for col in 0..<Self.bufferCols {
                buffer[row][col] = " "
            }
        }
    }

    func writeString(_ text: String, row: Int, col: Int) {
        guard row >= 0 && row < Self.bufferRows else { return }
        var currentCol = col
        for char in text {
            guard currentCol >= 0 && currentCol < Self.bufferCols else { break }
            buffer[row][currentCol] = char
            currentCol += 1
        }
    }

    func writeCentered(_ text: String, row: Int) {
        let startCol = max(0, (Self.bufferCols - text.count) / 2)
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

        writeString(String(repeating: "+", count: Self.bufferCols), row: 0, col: 0)
        writeCentered("PLAINTEXT PANIC", row: 1)
        writeString(String(repeating: "+", count: Self.bufferCols), row: 2, col: 0)

        writeCentered("FIND WORDS", row: 4)
        writeCentered("EACH ROUND IS 2 MINUTES", row: 5)
        writeCentered("TIME BONUS FOR 5, 6, AND 7-LETTER WORDS", row: 6)
        writeCentered("FIND THE 7-LETTER BINGO", row: 7)
        writeCentered("MEET THE POINT TARGET TO CONTINUE!", row: 8)

        writeString(String(repeating: "-", count: Self.bufferCols), row: 10, col: 0)
        writeCentered("SCORING:", row: 11)
        writeString("3-LETTER: 50", row: 12, col: 2)
        writeString("4-LETTER: 75", row: 12, col: 21)
        writeString("5-LETTER: 100", row: 13, col: 2)
        writeString("6-LETTER: 200", row: 13, col: 21)
        writeCentered("7-LETTER: 300", row: 14)

        writeString(String(repeating: "-", count: Self.bufferCols), row: 16, col: 0)

        writeCentered("[ENTER] START   [H] HIGH SCORES", row: 18)
        writeCentered("[CMD-Q] QUIT", row: 19)
    }

    func refreshGameDisplay() {
        // Don't refresh if showing a flash screen
        guard flashOverlay == .none else { return }

        clearBuffer()

        // Line 0-2: Title
        writeString(String(repeating: "+", count: Self.bufferCols), row: 0, col: 0)
        writeCentered("PLAINTEXT PANIC", row: 1)
        writeString(String(repeating: "+", count: Self.bufferCols), row: 2, col: 0)

        // Line 3: Score/target (left), Round (center), Time (right)
        writeString(String(format: "PTS:%03d/%03d", roundScore, minScoreRequired), row: 3, col: 1)
        writeCentered(String(format: "ROUND:%02d", level), row: 3)
        // Show time bonus display or actual time
        if let bonus = timeBonusDisplay {
            writeString("TIME: \(bonus)", row: 3, col: 31)
        } else {
            writeString(String(format: "TIME:%03d", timeLeft), row: 3, col: 31)
        }

        // Line 4: Separator
        writeString(String(repeating: "-", count: Self.bufferCols), row: 4, col: 0)

        // Line 5-6: Column headers with found/total counts
        writeString(wordCountHeader(), row: 5, col: 0)
        writeString(" ------    ------    ------    ------", row: 6, col: 0)

        // Lines 7-14: Word Matrix
        renderWordMatrix()

        // Line 15-16: Bingo area (multi-bingo support)
        renderBingoArea()

        // Line 17: Separator
        writeString(String(repeating: "-", count: Self.bufferCols), row: 17, col: 0)

        // Line 19: Pool letters (wide spacing, typed letters become spaces)
        let poolStr = poolDisplay.map { String($0) }.joined(separator: "   ")
        writeCentered(poolStr, row: 19)

        // Line 21: Input
        // Use block cursor (█) when visible, space when not
        let cursor = cursorVisible ? "\u{2588}" : " "  // █ or space
        let inputDisplay = "INPUT: > \(userInput)\(cursor)"
        writeString(inputDisplay, row: 21, col: 1)

        // Line 22: Separator
        writeString(String(repeating: "-", count: Self.bufferCols), row: 22, col: 0)

        // Line 23: Status
        if !statusMessage.isEmpty {
            writeCentered(statusMessage, row: 23)
        } else {
            writeCentered("[SPC]SHUFFLE [TAB]HINT [ESC]PAUSE", row: 23)
        }
    }

    func refreshRevealDisplay() {
        clearBuffer()

        // Line 0-2: Title
        writeString(String(repeating: "+", count: Self.bufferCols), row: 0, col: 0)
        writeCentered("ROUND COMPLETE", row: 1)
        writeString(String(repeating: "+", count: Self.bufferCols), row: 2, col: 0)

        // Line 3: Round score/target and total
        let scoreStr = String(format: " RD:%02d +%03d/%03d PTS TOTAL:%06d", level, roundScore, minScoreRequired, score)
        writeString(scoreStr, row: 3, col: 0)

        // Line 4: Separator
        writeString(String(repeating: "-", count: Self.bufferCols), row: 4, col: 0)

        // Line 5-6: Column headers with found/total counts
        writeString(wordCountHeader(), row: 5, col: 0)
        writeString(" ------    ------    ------    ------", row: 6, col: 0)

        // Lines 7-14: Full word matrix (with scroll)
        renderRevealWordMatrix()

        // Line 15: Separator
        writeString(String(repeating: "-", count: Self.bufferCols), row: 15, col: 0)

        // Line 16-20: All bingos
        renderRevealBingos()

        // Line 21: Separator or scroll indicator
        let isScrollable = getMaxWordCount() > 8
        if isScrollable {
            writeCentered("[UP/DOWN] SCROLL", row: 21)
        } else {
            writeString(String(repeating: "-", count: Self.bufferCols), row: 21, col: 0)
        }

        // Line 22-23: Instructions based on score
        if roundScore >= minScoreRequired {
            writeCentered("[ENTER] NEXT ROUND   [D] DEFINITIONS", row: 22)
        } else {
            writeCentered("NOT ENOUGH POINTS   [D] DEFINITIONS", row: 22)
        }
        writeCentered("[ESC] END   [H] HIGH SCORES", row: 23)
    }

    func showPausedScreen() {
        clearBuffer()
        writeString(String(repeating: "+", count: Self.bufferCols), row: 0, col: 0)
        writeString(String(repeating: "+", count: Self.bufferCols), row: 23, col: 0)
        writeCentered("PAUSED", row: 11)
        writeCentered("[ESC] END ROUND   [ANY KEY] RESUME", row: 13)
        objectWillChange.send()
    }

    func showHighScoreEntryScreen() {
        clearBuffer()
        writeString(String(repeating: "+", count: Self.bufferCols), row: 0, col: 0)
        writeCentered("NEW HIGH SCORE!", row: 1)
        writeString(String(repeating: "+", count: Self.bufferCols), row: 2, col: 0)

        writeCentered(String(format: "SCORE: %06d", score), row: 5)
        writeCentered(String(format: "ROUND: %02d", level), row: 7)

        writeString(String(repeating: "-", count: Self.bufferCols), row: 10, col: 0)
        writeCentered("ENTER YOUR INITIALS:", row: 12)

        // Show initials being entered
        let display = highScoreInitials.padding(toLength: 3, withPad: "_", startingAt: 0)
        writeCentered("[ \(display.map { String($0) }.joined(separator: " ")) ]", row: 14)

        writeString(String(repeating: "-", count: Self.bufferCols), row: 17, col: 0)
        writeCentered("[A-Z] ENTER INITIALS", row: 19)
        writeCentered("[BACKSPACE] DELETE", row: 20)
        writeCentered("[ENTER] CONFIRM", row: 21)
    }

    func showHighScoreList(fromReveal: Bool = false) {
        cameFromRevealScreen = fromReveal
        gameMode = .highScoreList
        clearBuffer()
        writeString(String(repeating: "+", count: Self.bufferCols), row: 0, col: 0)
        writeCentered("HIGH SCORES", row: 1)
        writeString(String(repeating: "+", count: Self.bufferCols), row: 2, col: 0)

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

        writeString(String(repeating: "-", count: Self.bufferCols), row: 18, col: 0)
        if cameFromRevealScreen {
            writeCentered("[ENTER] BACK   [ESC] END GAME", row: 20)
        } else {
            writeCentered("[ENTER] BACK TO TITLE", row: 20)
        }
    }

    // MARK: - Word Matrix Rendering

    fileprivate func renderRevealWordMatrix() {
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

        // Mark found vs unfound: found in UPPER, unfound prefixed with .
        func formatWord(_ word: String) -> String {
            if foundWords.contains(word) {
                return word  // Found words shown normally (UPPERCASE)
            } else {
                return "." + word.lowercased()  // Unfound: .lowercase for visibility
            }
        }

        let display3 = words3.map { formatWord($0) }
        let display4 = words4.map { formatWord($0) }
        let display5 = words5.map { formatWord($0) }
        let display6 = words6.map { formatWord($0) }

        renderWordColumns(display3, display4, display5, display6, offset: revealScrollOffset)
    }

    fileprivate func renderWordMatrix() {
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

        renderWordColumns(display3, display4, display5, display6, offset: gameScrollOffset)
    }

    /// Shared rendering for 4-column word matrix used by both gameplay and reveal screens
    private func renderWordColumns(_ display3: [String], _ display4: [String], _ display5: [String], _ display6: [String], offset: Int) {
        let maxRows = 8

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

    // MARK: - Bingo Area Rendering

    fileprivate func renderBingoArea() {
        // Show all possible 7-letter bingos
        if bingoWords.isEmpty {
            writeCentered("7-LETTER BINGO: (NONE)", row: 16)
            return
        }

        if bingoWords.count == 1 {
            // Single bingo - original format
            let word = bingoWords[0]
            let display: String
            if foundBingos.contains(word) {
                display = word.map { String($0) }.joined(separator: " ")
            } else if hintBingoWord == word {
                display = buildHintDisplay(word: word, spaced: true)
            } else {
                display = "_ _ _ _ _ _ _"
            }
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
                } else if hintBingoWord == word {
                    allDisplays.append(buildHintDisplay(word: word, spaced: false))
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

    fileprivate func renderRevealBingos() {
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

    // MARK: - Display Helpers

    func getMaxWordCount() -> Int {
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

    fileprivate func wordCountsByLength() -> (found: [Int: Int], total: [Int: Int]) {
        var found: [Int: Int] = [3: 0, 4: 0, 5: 0, 6: 0]
        var total: [Int: Int] = [3: 0, 4: 0, 5: 0, 6: 0]
        for (word, length) in allValidWords {
            guard length >= 3 && length <= 6 else { continue }
            total[length, default: 0] += 1
            if foundWords.contains(word) {
                found[length, default: 0] += 1
            }
        }
        return (found, total)
    }

    fileprivate func wordCountHeader() -> String {
        let counts = wordCountsByLength()
        func col(_ len: Int) -> String { "\(len):\(counts.found[len]!)/\(counts.total[len]!)" }
        return " " + col(3).padding(toLength: 10, withPad: " ", startingAt: 0)
             + col(4).padding(toLength: 10, withPad: " ", startingAt: 0)
             + col(5).padding(toLength: 10, withPad: " ", startingAt: 0)
             + col(6)
    }

    func hasMoreWordsToShow() -> Bool {
        return (revealScrollOffset + 8) < getMaxWordCount()
    }

    func hasMoreGameWordsToShow() -> Bool {
        return (gameScrollOffset + 8) < getMaxWordCount()
    }

    func buildHintDisplay(word: String, spaced: Bool) -> String {
        let chars = Array(word)
        var parts: [String] = []
        for (i, char) in chars.enumerated() {
            if hintRevealedPositions.contains(i) {
                parts.append(String(char))
            } else {
                parts.append("_")
            }
        }
        return spaced ? parts.joined(separator: " ") : parts.joined()
    }

    // MARK: - Flash Screens

    func triggerBingoFlash(hintPenalty: Bool = false) {
        // Save current buffer (deep copy)
        savedBuffer = buffer.map { $0 }
        flashOverlay = .bingo

        // Render BINGO to buffer
        clearBuffer()

        // Add edge content so barrel distortion is visible
        // (distortion is minimal at center, maximal at edges)
        writeString(String(repeating: "+", count: Self.bufferCols), row: 0, col: 0)
        writeString(String(repeating: "+", count: Self.bufferCols), row: 23, col: 0)

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

        if hintPenalty {
            writeCentered("(HINT USED: HALF POINTS)", row: 16)
        }

        // Force view update after all writes
        objectWillChange.send()

        // Restore after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.flashOverlay == .bingo else { return }
            self.flashOverlay = .none
            if let saved = self.savedBuffer {
                self.buffer = saved.map { $0 }
                self.savedBuffer = nil
                self.objectWillChange.send()
            }
        }
    }

    func showWowScreen() {
        // Save current buffer (deep copy) and show WOW screen
        savedBuffer = buffer.map { $0 }
        flashOverlay = .wow

        clearBuffer()

        // Add edge content so barrel distortion is visible
        // (distortion is minimal at center, maximal at edges)
        writeString(String(repeating: "+", count: Self.bufferCols), row: 0, col: 0)
        writeString(String(repeating: "+", count: Self.bufferCols), row: 23, col: 0)

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

    func dismissWowScreen() {
        flashOverlay = .none
        savedBuffer = nil  // Don't restore - we're going to reveal screen
        showRevealScreen()
    }

    // MARK: - Status & Time Bonus

    func applyTimeBonus(seconds: Int, displayAs: String) {
        timeLeft += seconds
        timeBonusDisplay = displayAs
        refreshGameDisplay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.timeBonusDisplay = nil
            self?.refreshGameDisplay()
        }
    }

    func setStatusMessage(_ message: String, clearAfter seconds: Double = 2.0) {
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
