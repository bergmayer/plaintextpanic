# Plaintext Panic

A retro word puzzle game for macOS with Apple II-style aesthetics.  Find as many words as you can with the provided letters.   Every round has at least one seven-letter "Bingo."

## Features

- CRT monitor 
- Typing
- Multiple word lists to choose from
- Word definitions viewer
- Wow

## Building

Requires Xcode with macOS SDK.

```bash
./build.sh debug    # Build debug configuration
./build.sh release  # Build release configuration
./build.sh clean    # Clean build artifacts
./build.sh run      # Build debug and launch
```

## Word List

This game uses word lists from the North American SCRABBLE Players Association (NASPA).

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
