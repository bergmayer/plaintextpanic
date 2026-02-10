import SwiftUI
import AppKit

// MARK: - Help Content Row Views

struct HelpSectionHeader: View {
    let title: String
    let rowIndex: Int
    let lineHeight: CGFloat = 33
    let inkColor = Color(red: 0.17, green: 0.17, blue: 0.17)

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            Text(title)
                .font(.custom("Courier", size: 21).bold())
                .foregroundColor(inkColor)
        }
    }
}

struct HelpTextRow: View {
    let text: String
    let rowIndex: Int
    let lineHeight: CGFloat = 33
    let inkColor = Color(red: 0.17, green: 0.17, blue: 0.17)

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            HStack {
                Text(text)
                    .font(.custom("Courier", size: 18))
                    .foregroundColor(inkColor.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, 12)
        }
    }
}

struct HelpLinkRow: View {
    let text: String
    let url: URL
    let rowIndex: Int
    let lineHeight: CGFloat = 33

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            HStack {
                Link(text, destination: url)
                    .font(.custom("Courier", size: 18))
                    .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.6))
                Spacer()
            }
            .padding(.horizontal, 12)
        }
    }
}

struct HelpLogoRow: View {
    let rowIndex: Int
    let rowSpan: Int
    let lineHeight: CGFloat = 33
    let naspaURL = URL(string: "https://www.scrabbleplayers.org")!

    var body: some View {
        ZStack {
            // Background spans multiple rows
            VStack(spacing: 0) {
                ForEach(0..<rowSpan, id: \.self) { i in
                    GreenBarRow(index: rowIndex + i, height: lineHeight)
                }
            }
            // Logo as clickable link
            Link(destination: naspaURL) {
                if let nsImage = NSImage(named: "NASPA_logo_small") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: CGFloat(rowSpan) * lineHeight - 12)
                } else {
                    Text("[NASPA Logo]")
                        .font(.custom("Courier", size: 18))
                        .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.6))
                }
            }
        }
        .frame(height: CGFloat(rowSpan) * lineHeight)
    }
}

// MARK: - Help Window View

struct HelpWindow: View {
    @Environment(\.dismiss) private var dismiss

    // Help content as rows
    // Time Bonuses moved to be right after Rounds & Timing
    private let content: [(type: RowType, text: String)] = [
        (.header, "PLAINTEXT PANIC - HOW TO PLAY"),
        (.separator, ""),
        (.section, "THE BASICS"),
        (.text, "Each round you get 7 letters. Find as many words as you can before time runs out!"),
        (.text, "Type a word and press ENTER to submit."),
        (.empty, ""),
        (.separator, ""),
        (.section, "ROUNDS & TIMING"),
        (.text, "Each round lasts 2 minutes."),
        (.text, "Score enough points to advance."),
        (.text, "The target starts at 400 and increases"),
        (.text, "by 25 each round, up to a max of 525."),
        (.text, "The game ends when you miss the target."),
        (.empty, ""),
        (.separator, ""),
        (.section, "TIME BONUSES"),
        (.text, "Longer words add time to the clock:"),
        (.text, "  5-letter words:  +5 seconds"),
        (.text, "  6-letter words: +10 seconds"),
        (.text, "  7-letter words: +20 seconds"),
        (.empty, ""),
        (.text, "The BINGO display adds 1 extra second."),
        (.empty, ""),
        (.separator, ""),
        (.section, "SCORING"),
        (.text, "  3-letter words:  50 points"),
        (.text, "  4-letter words:  75 points"),
        (.text, "  5-letter words: 100 points"),
        (.text, "  6-letter words: 200 points"),
        (.text, "  7-letter words: 300 points (BINGO!)"),
        (.empty, ""),
        (.separator, ""),
        (.section, "CONTROLS"),
        (.text, "  [A-Z]       Type letters"),
        (.text, "  [ENTER]     Submit word"),
        (.text, "  [BACKSPACE] Delete letter"),
        (.text, "  [SPACE]     Shuffle letters"),
        (.text, "  [TAB]       Bingo hint (1 per round)"),
        (.text, "  [UP/DOWN]   Scroll word lists"),
        (.text, "  [ESC]       Pause (ESC again to end)"),
        (.text, "  [D]         View definitions (after round)"),
        (.empty, ""),
        (.separator, ""),
        (.section, "BINGO HINT"),
        (.text, "Press TAB once per round to reveal"),
        (.text, "3 letters of an unfound bingo word."),
        (.text, "The first, last, and one random"),
        (.text, "middle letter are shown."),
        (.empty, ""),
        (.separator, ""),
        (.section, "SOUND"),
        (.text, "Retro sound effects can be toggled"),
        (.text, "from the View menu."),
        (.empty, ""),
        (.separator, ""),
        (.section, "WORD LIST"),
        (.text, "Two options (change from menu):"),
        (.empty, ""),
        (.text, "  Full NASPA Word List (default)"),
        (.text, "    All 25,473 tournament 7-letter words"),
        (.empty, ""),
        (.text, "  Common 7-Letter Words"),
        (.text, "    5,060 recognizable 7-letter words"),
        (.empty, ""),
        (.logo, ""),  // 3-row logo display
        (.link, "NASPA Word List 2023 Edition"),
        (.text, "\u{00A9} NASPA 2025"),
        (.empty, ""),
        (.text, "The copy included in this app is"),
        (.text, "licensed for personal use. You may"),
        (.text, "not use it for any commercial purposes."),
        (.empty, ""),
        (.separator, ""),
        (.section, "FONTS"),
        (.fontLink, "Fonts by Kreative Korp"),
        (.empty, ""),
        (.empty, ""),
    ]

    enum RowType {
        case header, section, text, separator, empty, link, logo, fontLink
    }

    private let logoRowSpan = 3

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(content.enumerated()), id: \.offset) { index, row in
                        if row.type == .logo {
                            // Logo spans multiple rows
                            PaperRowMulti(startIndex: index, count: logoRowSpan, lineHeight: 33) {
                                HelpLogoRow(rowIndex: index, rowSpan: logoRowSpan)
                            }
                        } else {
                            PaperRow(rowIndex: index, lineHeight: 33) {
                                rowContent(for: row, at: index)
                            }
                        }
                    }

                    // Bottom padding rows
                    ForEach(0..<4, id: \.self) { i in
                        let idx = content.count + i
                        PaperRow(rowIndex: idx, lineHeight: 33) {
                            EmptyContentRow(rowIndex: idx, lineHeight: 33)
                        }
                    }
                }
            }
            .background(Color(red: 0.2, green: 0.2, blue: 0.2))
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            .background(
                Button("") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .opacity(0)
            )
        }
        .frame(width: 630, height: 750)
    }

    private let naspaURL = URL(string: "https://www.scrabbleplayers.org")!
    private let kreativeURL = URL(string: "https://www.kreativekorp.com/software/fonts/apple2/")!

    @ViewBuilder
    private func rowContent(for row: (type: RowType, text: String), at index: Int) -> some View {
        switch row.type {
        case .header:
            HelpSectionHeader(title: row.text, rowIndex: index)
        case .section:
            HelpSectionHeader(title: row.text, rowIndex: index)
        case .text:
            HelpTextRow(text: row.text, rowIndex: index)
        case .separator:
            DottedSeparatorContentRow(rowIndex: index, lineHeight: 33)
        case .empty:
            EmptyContentRow(rowIndex: index, lineHeight: 33)
        case .link:
            HelpLinkRow(text: row.text, url: naspaURL, rowIndex: index)
        case .fontLink:
            HelpLinkRow(text: row.text, url: kreativeURL, rowIndex: index)
        case .logo:
            // Logo is handled specially in the body - show empty row as placeholder
            EmptyContentRow(rowIndex: index, lineHeight: 33)
        }
    }
}

// MARK: - Window Controller
//
// Uses same crash prevention patterns as DefinitionsWindowController.
// See DefinitionsWindow.swift for detailed explanation.

class HelpWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var hostingController: NSHostingController<HelpWindow>?

    func show() {
        // Close existing window safely before creating new one
        if window != nil {
            performSafeClose()
        }

        let contentView = HelpWindow()
        let hosting = NSHostingController(rootView: contentView)
        hostingController = hosting

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 630, height: 750),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // CRASH PREVENTION: Disable all animations
        newWindow.animationBehavior = .none

        // CRASH PREVENTION: Don't auto-release window when closed
        newWindow.isReleasedWhenClosed = false

        newWindow.contentViewController = hosting
        newWindow.title = "How to Play"
        newWindow.delegate = self
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow
    }

    func close() {
        performSafeClose()
    }

    private func performSafeClose() {
        guard let w = window else { return }

        w.delegate = nil
        w.contentViewController = nil
        w.animationBehavior = .none
        w.close()

        let windowToRelease = w
        let hostingToRelease = hostingController

        self.window = nil
        self.hostingController = nil

        DispatchQueue.main.async {
            _ = windowToRelease
            _ = hostingToRelease
        }
    }

    // NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else { return }

        closingWindow.contentViewController = nil

        let windowToRelease = window
        let hostingToRelease = hostingController

        window = nil
        hostingController = nil

        DispatchQueue.main.async {
            _ = windowToRelease
            _ = hostingToRelease
        }
    }
}
