import Foundation

// MARK: - Input Handling
// All keyboard input handling and word submission methods for GameEngine.

extension GameEngine {

    // MARK: - Key Handlers

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

        // Playing - but first check if paused or flash screens are showing
        if isPaused {
            isPaused = false
            refreshGameDisplay()
            return
        }

        if flashOverlay == .bingo {
            // Ignore all keys during BINGO flash
            return
        }

        if flashOverlay == .wow {
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
                soundEffects.playKeystroke()
                if !isStressTestMode {
                    updatePoolDisplay()
                }
                statusMessage = ""
                refreshGameDisplay()
            }
        }
    }

    func handleHint() {
        guard gameMode == .playing, !isPaused else { return }
        guard flashOverlay == .none else { return }

        // Check if all bingos already found
        if foundBingos.count == bingoWords.count || bingoWords.isEmpty {
            setStatusMessage("* ALL BINGOS FOUND *")
            return
        }

        // Check if hint already used this round
        if hintUsed {
            setStatusMessage("* NO HINTS LEFT *")
            return
        }

        // Pick first unfound bingo alphabetically
        let sortedBingos = bingoWords.sorted()
        guard let targetBingo = sortedBingos.first(where: { !foundBingos.contains($0) }) else {
            setStatusMessage("* ALL BINGOS FOUND *")
            return
        }

        hintUsed = true
        hintBingoWord = targetBingo

        // Reveal first letter, last letter, and one random middle letter
        hintRevealedPositions = [0, targetBingo.count - 1]
        if targetBingo.count > 2 {
            let randomMiddle = (1..<(targetBingo.count - 1)).randomElement()!
            hintRevealedPositions.insert(randomMiddle)
        }

        setStatusMessage("* HINT USED *")
    }

    func handleArrowKey(isUp: Bool) {
        if gameMode == .playing, !isPaused {
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

        if gameMode == .playing, !isPaused {
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

    func closeDefinitionsWindow() -> Bool {
        return definitionsWindowController.closeIfOpen()
    }

    // MARK: - Word Submission

    private func submitWord() {
        let word = userInput.uppercased()
        userInput = ""
        updatePoolDisplay()  // Reset pool display

        guard word.count >= 3 else {
            soundEffects.playInvalidBuzz()
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
            soundEffects.playInvalidBuzz()
            setStatusMessage("* INVALID LETTERS *")
            return
        }

        guard lexicon.isValidWord(word) else {
            soundEffects.playInvalidBuzz()
            setStatusMessage("* NOT A VALID WORD *")
            return
        }

        guard !foundWords.contains(word) else {
            soundEffects.playInvalidBuzz()
            setStatusMessage("* DUPLICATE WORD *")
            return
        }

        // Valid word!
        foundWords.insert(word)
        var points = scoreForWord(length: word.count)
        // Half points for bingos when hint was used
        let bingoHintPenalty = word.count == 7 && bingoWords.contains(word) && hintUsed
        if bingoHintPenalty {
            points = points / 2
        }
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
                // Flash BINGO! overlay and fanfare
                soundEffects.playBingoFanfare()
                triggerBingoFlash(hintPenalty: bingoHintPenalty)
            }
            // +21 seconds (accounts for 1s bingo display), shown as +20
            applyTimeBonus(seconds: 21, displayAs: "+20")
        case 6:
            soundEffects.playValidWord()
            applyTimeBonus(seconds: 10, displayAs: "+10")
        case 5:
            soundEffects.playValidWord()
            applyTimeBonus(seconds: 5, displayAs: "+5")
        default:
            soundEffects.playValidWord()
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

    // MARK: - Helpers

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

    func scoreForWord(length: Int) -> Int {
        switch length {
        case 3: return 50
        case 4: return 75
        case 5: return 100
        case 6: return 200
        case 7: return 300
        default: return 0
        }
    }
}
