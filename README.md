# Plaintext Panic

A retro word puzzle game for macOS with Apple II-style aesthetics.  Find as many words as you can with the provided letters.   Every round has at least one seven-letter "Bingo."

## Features

- Apple II CRT monitor aesthetic with barrel distortion and scanlines
- Progressive difficulty: point target starts at 400 and increases by 25 each round (max 525)
- One bingo hint per round (TAB key) reveals 3 letters of an unfound 7-letter word
- Apple II-style square wave sound effects (toggle from View menu)
- Pause mid-round with ESC (hides the board; ESC again to end round)
- Dynamic column headers showing found/total word counts per length
- Multiple word lists to choose from
- Word definitions viewer
- Green, amber, or white phosphor display

## Building

Requires Xcode with macOS SDK.

```bash
./build.sh debug    # Build debug configuration
./build.sh release  # Build release configuration
./build.sh clean    # Clean build artifacts
./build.sh run      # Build debug and launch
```

## Controls

| Key | Action |
|-----|--------|
| A-Z | Type letters |
| ENTER | Submit word |
| BACKSPACE | Delete letter |
| SPACE | Shuffle letters |
| TAB | Bingo hint (one per round) |
| UP/DOWN | Scroll word lists |
| LEFT/RIGHT | Scroll bingos |
| ESC | Pause (ESC again to end round) |
| D | View definitions (after round) |
| H | View high scores |
| ? | How to Play |

## Word Lists

This game uses word lists from the North American SCRABBLE Players Association (NASPA). Two word list options are available from the menu:

**Full NASPA Word List** (default)
All valid tournament words from the NASPA Word List 2023. Includes 25,473 possible 7-letter starting words.

**Common 7-Letter Words**
Uses only common, recognizable 7-letter words (5,060 words) while keeping all 3-6 letter words playable. Good for casual play.

---

**NASPA Word List 2023 Edition**
**© NASPA 2025**

The copy included in this app is licensed for personal use. You may not use it for any commercial purposes.

For more information, visit [www.scrabbleplayers.org](https://www.scrabbleplayers.org)

## License

### Application Source Code

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. Copyright (c) 2025 John Bergmayer

See [LICENSE](LICENSE) for the full GPL 3.0 text.

### Fonts

This application uses fonts from [Kreative Korp](https://www.kreativekorp.com/software/fonts/apple2/):
- PrintChar21
- PRNumber3

These fonts are used under the Kreative Software Relay Fonts Free Use License. See [FontLicense.txt](PlaintextPanic/Resources/FontLicense.txt) for the full license text.
