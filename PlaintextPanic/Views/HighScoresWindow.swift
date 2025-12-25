import SwiftUI
import AppKit

// MARK: - High Scores Content Row Views

struct HighScoresHeaderRow: View {
    let rowIndex: Int
    let lineHeight: CGFloat = 33
    let inkColor = Color(red: 0.17, green: 0.17, blue: 0.17)

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            Text("HIGH SCORES")
                .font(.custom("Courier", size: 21).bold())
                .foregroundColor(inkColor)
        }
    }
}

struct HighScoresColumnHeaderRow: View {
    let rowIndex: Int
    let lineHeight: CGFloat = 33
    let inkColor = Color(red: 0.17, green: 0.17, blue: 0.17)

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            HStack {
                Text(" ##")
                    .frame(width: 50, alignment: .leading)
                Text("NAME")
                    .frame(width: 80, alignment: .leading)
                Text("SCORE")
                    .frame(width: 100, alignment: .trailing)
                Text("ROUND")
                    .frame(width: 80, alignment: .trailing)
                Spacer()
            }
            .font(.custom("Courier", size: 16).bold())
            .foregroundColor(inkColor)
            .padding(.horizontal, 12)
        }
    }
}

struct HighScoreEntryRow: View {
    let rank: Int
    let entry: HighScoreEntry
    let rowIndex: Int
    let lineHeight: CGFloat = 33
    let inkColor = Color(red: 0.17, green: 0.17, blue: 0.17)

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            HStack {
                Text(String(format: "%2d.", rank))
                    .frame(width: 50, alignment: .leading)
                // Pad initials to 3 characters
                Text(entry.initials.padding(toLength: 3, withPad: " ", startingAt: 0))
                    .frame(width: 80, alignment: .leading)
                Text(String(format: "%06d", entry.score))
                    .frame(width: 100, alignment: .trailing)
                Text(String(format: "%02d", entry.round))
                    .frame(width: 80, alignment: .trailing)
                Spacer()
            }
            .font(.custom("Courier", size: 16))
            .foregroundColor(inkColor.opacity(0.85))
            .padding(.horizontal, 12)
        }
    }
}

struct NoHighScoresRow: View {
    let rowIndex: Int
    let lineHeight: CGFloat = 33
    let inkColor = Color(red: 0.17, green: 0.17, blue: 0.17)

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            Text("NO HIGH SCORES YET")
                .font(.custom("Courier", size: 16))
                .foregroundColor(inkColor.opacity(0.7))
        }
    }
}

// MARK: - High Scores Window View

struct HighScoresWindow: View {
    let highScores: [HighScoreEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Row 0: Header
                PaperRow(rowIndex: 0, lineHeight: 33) {
                    HighScoresHeaderRow(rowIndex: 0)
                }

                // Row 1: Separator
                PaperRow(rowIndex: 1, lineHeight: 33) {
                    DottedSeparatorContentRow(rowIndex: 1, lineHeight: 33)
                }

                // Row 2: Column headers
                PaperRow(rowIndex: 2, lineHeight: 33) {
                    HighScoresColumnHeaderRow(rowIndex: 2)
                }

                // Row 3: Separator under headers
                PaperRow(rowIndex: 3, lineHeight: 33) {
                    DottedSeparatorContentRow(rowIndex: 3, lineHeight: 33)
                }

                // Rows 4-13: High score entries (or empty message)
                if highScores.isEmpty {
                    // Show empty message
                    ForEach(0..<3, id: \.self) { i in
                        PaperRow(rowIndex: 4 + i, lineHeight: 33) {
                            EmptyContentRow(rowIndex: 4 + i, lineHeight: 33)
                        }
                    }
                    PaperRow(rowIndex: 7, lineHeight: 33) {
                        NoHighScoresRow(rowIndex: 7)
                    }
                    ForEach(0..<3, id: \.self) { i in
                        PaperRow(rowIndex: 8 + i, lineHeight: 33) {
                            EmptyContentRow(rowIndex: 8 + i, lineHeight: 33)
                        }
                    }
                } else {
                    // Show high scores
                    ForEach(0..<10, id: \.self) { i in
                        let rowIdx = 4 + i
                        if i < highScores.count {
                            PaperRow(rowIndex: rowIdx, lineHeight: 33) {
                                HighScoreEntryRow(rank: i + 1, entry: highScores[i], rowIndex: rowIdx)
                            }
                        } else {
                            PaperRow(rowIndex: rowIdx, lineHeight: 33) {
                                EmptyContentRow(rowIndex: rowIdx, lineHeight: 33)
                            }
                        }
                    }
                }

                // Bottom separator
                PaperRow(rowIndex: 14, lineHeight: 33) {
                    DottedSeparatorContentRow(rowIndex: 14, lineHeight: 33)
                }

                // Bottom padding rows
                ForEach(0..<3, id: \.self) { i in
                    let idx = 15 + i
                    PaperRow(rowIndex: idx, lineHeight: 33) {
                        EmptyContentRow(rowIndex: idx, lineHeight: 33)
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
        .frame(width: 450, height: 594)  // 18 rows * 33 height
    }
}

// MARK: - Window Controller
//
// Uses same crash prevention patterns as DefinitionsWindowController.
// See DefinitionsWindow.swift for detailed explanation.

class HighScoresWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var hostingController: NSHostingController<HighScoresWindow>?

    func show(highScores: [HighScoreEntry]) {
        // Close existing window safely before creating new one
        if window != nil {
            performSafeClose()
        }

        let contentView = HighScoresWindow(highScores: highScores)
        let hosting = NSHostingController(rootView: contentView)
        hostingController = hosting

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 594),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // CRASH PREVENTION: Disable all animations
        newWindow.animationBehavior = .none

        // CRASH PREVENTION: Don't auto-release window when closed
        newWindow.isReleasedWhenClosed = false

        newWindow.contentViewController = hosting
        newWindow.title = "High Scores"
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
