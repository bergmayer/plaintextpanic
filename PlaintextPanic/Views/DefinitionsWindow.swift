import SwiftUI
import AppKit

struct WordWithDefinition: Identifiable {
    let id = UUID()
    let word: String
    let definition: String
    let wasFound: Bool
}

// MARK: - Sprocket Hole Row (single row height)

struct SprocketHoleRow: View {
    let rowIndex: Int
    let lineHeight: CGFloat
    let holeSize: CGFloat = 8
    let stripWidth: CGFloat = 30

    init(rowIndex: Int, lineHeight: CGFloat = 22) {
        self.rowIndex = rowIndex
        self.lineHeight = lineHeight
    }

    var body: some View {
        ZStack {
            // Strip background
            Color(red: 0.95, green: 0.95, blue: 0.93)

            // Hole centered in row
            Circle()
                .fill(Color(red: 0.4, green: 0.4, blue: 0.4))
                .frame(width: holeSize, height: holeSize)
        }
        .frame(width: stripWidth, height: lineHeight)
    }
}

struct PerforationSegment: View {
    let lineHeight: CGFloat

    init(lineHeight: CGFloat = 22) {
        self.lineHeight = lineHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                if i % 2 == 0 {
                    Rectangle()
                        .fill(Color(red: 0.75, green: 0.75, blue: 0.75))
                        .frame(width: 1, height: 3)
                } else {
                    Spacer().frame(height: 3)
                }
            }
            Spacer()
        }
        .frame(width: 2, height: lineHeight)
    }
}

// MARK: - Complete Paper Row (sprockets + content + sprockets)

struct PaperRow<Content: View>: View {
    let rowIndex: Int
    let content: Content
    let lineHeight: CGFloat

    init(rowIndex: Int, lineHeight: CGFloat = 22, @ViewBuilder content: () -> Content) {
        self.rowIndex = rowIndex
        self.lineHeight = lineHeight
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            SprocketHoleRow(rowIndex: rowIndex, lineHeight: lineHeight)
            content
            SprocketHoleRow(rowIndex: rowIndex, lineHeight: lineHeight)
        }
        .frame(height: lineHeight)
    }
}

// MARK: - Green Bar Row (single row)

struct GreenBarRow: View {
    let index: Int
    let height: CGFloat
    let greenBarColor = Color(red: 0.88, green: 0.95, blue: 0.89)

    var body: some View {
        Rectangle()
            .fill(index % 2 == 0 ? greenBarColor : Color.white)
            .frame(height: height)
    }
}

struct DottedSeparator: View {
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<Int(geometry.size.width / 8), id: \.self) { _ in
                    Circle()
                        .fill(Color(red: 0.5, green: 0.5, blue: 0.5))
                        .frame(width: 2, height: 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Content Row Views (just the middle content, no sprockets)

struct HeaderContentRow: View {
    let foundCount: Int
    let totalCount: Int
    let rowIndex: Int
    let lineHeight: CGFloat = 28
    let inkColor = Color(red: 0.17, green: 0.17, blue: 0.17)

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            HStack {
                Text("WORD DEFINITIONS")
                    .font(.custom("Courier", size: 20).bold())
                    .foregroundColor(inkColor)
                Spacer()
                Text("\(foundCount)/\(totalCount) found")
                    .font(.custom("Courier", size: 17))
                    .foregroundColor(inkColor.opacity(0.7))
            }
            .padding(.horizontal, 8)
        }
    }
}

struct DottedSeparatorContentRow: View {
    let rowIndex: Int
    let lineHeight: CGFloat

    init(rowIndex: Int, lineHeight: CGFloat = 22) {
        self.rowIndex = rowIndex
        self.lineHeight = lineHeight
    }

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            DottedSeparator()
        }
    }
}

struct SectionTitleContentRow: View {
    let title: String
    let rowIndex: Int
    let lineHeight: CGFloat = 28
    let inkColor = Color(red: 0.17, green: 0.17, blue: 0.17)

    var body: some View {
        ZStack {
            GreenBarRow(index: rowIndex, height: lineHeight)
            HStack {
                Text(title)
                    .font(.custom("Courier", size: 16).bold())
                    .foregroundColor(inkColor)
                Spacer()
            }
            .padding(.horizontal, 8)
        }
    }
}

struct WordContentRow: View {
    let word: String
    let definition: String
    let wasFound: Bool
    let rowIndex: Int
    let inkColor = Color(red: 0.17, green: 0.17, blue: 0.17)
    let greenBarColor = Color(red: 0.88, green: 0.95, blue: 0.89)

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(word)
                .font(.custom("Courier", size: 16).bold())
                .foregroundColor(wasFound ? inkColor : inkColor.opacity(0.5))
                .frame(width: 85, alignment: .leading)

            Image(systemName: wasFound ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17))
                .foregroundColor(wasFound ? Color(red: 0.2, green: 0.5, blue: 0.3) : inkColor.opacity(0.4))
                .frame(width: 22)
                .padding(.top, 2)

            Text(definition)
                .font(.custom("Courier", size: 15))
                .foregroundColor(inkColor.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(rowIndex % 2 == 0 ? greenBarColor : Color.white)
    }
}

struct EmptyContentRow: View {
    let rowIndex: Int
    let lineHeight: CGFloat

    init(rowIndex: Int, lineHeight: CGFloat = 22) {
        self.rowIndex = rowIndex
        self.lineHeight = lineHeight
    }

    var body: some View {
        GreenBarRow(index: rowIndex, height: lineHeight)
    }
}

// Helper view for word rows with sprockets that handles variable height content
struct WordRowWithSprockets<Content: View>: View {
    let rowIndex: Int
    let content: Content
    let sprocketColor = Color(red: 0.95, green: 0.95, blue: 0.93)

    init(rowIndex: Int, @ViewBuilder content: () -> Content) {
        self.rowIndex = rowIndex
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left sprocket strip
            Rectangle()
                .fill(sprocketColor)
                .frame(width: 30)
                .overlay(
                    Circle()
                        .fill(Color(red: 0.4, green: 0.4, blue: 0.4))
                        .frame(width: 8, height: 8)
                )

            // Content area
            content
                .frame(maxWidth: .infinity)

            // Right sprocket strip
            Rectangle()
                .fill(sprocketColor)
                .frame(width: 30)
                .overlay(
                    Circle()
                        .fill(Color(red: 0.4, green: 0.4, blue: 0.4))
                        .frame(width: 8, height: 8)
                )
        }
    }
}

// MARK: - Main Definitions Window

struct DefinitionsWindow: View {
    let words: [String: Int]
    let foundWords: Set<String>
    let lexicon: Lexicon

    @Environment(\.dismiss) private var dismiss

    private var wordsByLength: [(Int, [WordWithDefinition])] {
        var grouped: [Int: [WordWithDefinition]] = [:]

        for (word, length) in words {
            let definition = lexicon.getDefinition(for: word) ?? "No definition available"
            let wasFound = foundWords.contains(word)
            let entry = WordWithDefinition(word: word, definition: definition, wasFound: wasFound)

            if grouped[length] == nil {
                grouped[length] = []
            }
            grouped[length]!.append(entry)
        }

        for (length, entries) in grouped {
            grouped[length] = entries.sorted { $0.word < $1.word }
        }

        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable paper with sprockets
            ScrollView {
                VStack(spacing: 0) {
                    // Row 0: Header title
                    PaperRow(rowIndex: 0, lineHeight: 28) {
                        HeaderContentRow(foundCount: foundWords.count, totalCount: words.count, rowIndex: 0)
                    }

                    // Row 1: Dotted separator
                    PaperRow(rowIndex: 1, lineHeight: 28) {
                        DottedSeparatorContentRow(rowIndex: 1, lineHeight: 28)
                    }

                    // Word sections
                    let startRow = 2
                    ForEach(Array(wordsByLength.enumerated()), id: \.element.0) { sectionIndex, section in
                        let (length, entries) = section

                        // Calculate row index for this section (simplified - just track visually)
                        let sectionStartRow = startRow + sectionIndex * 4

                        // Dotted separator before section
                        PaperRow(rowIndex: sectionStartRow, lineHeight: 28) {
                            DottedSeparatorContentRow(rowIndex: sectionStartRow, lineHeight: 28)
                        }

                        // Section title
                        PaperRow(rowIndex: sectionStartRow + 1, lineHeight: 28) {
                            SectionTitleContentRow(title: "\(length)-LETTER WORDS (\(entries.count))", rowIndex: sectionStartRow + 1)
                        }

                        // All words: vertical list with word + checkbox + definition
                        ForEach(Array(entries.enumerated()), id: \.element.id) { entryIndex, entry in
                            WordRowWithSprockets(rowIndex: sectionStartRow + 2 + entryIndex) {
                                WordContentRow(
                                    word: entry.word,
                                    definition: entry.definition,
                                    wasFound: entry.wasFound,
                                    rowIndex: sectionStartRow + 2 + entryIndex
                                )
                            }
                        }
                    }

                    // Bottom padding rows
                    let totalRows = 2 + wordsByLength.reduce(0) { $0 + $1.1.count + 2 }
                    ForEach(0..<6, id: \.self) { i in
                        PaperRow(rowIndex: totalRows + i, lineHeight: 28) {
                            EmptyContentRow(rowIndex: totalRows + i, lineHeight: 28)
                        }
                    }
                }
            }
            .background(Color(red: 0.2, green: 0.2, blue: 0.2))
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            // Hidden button for ESC key handling
            .background(
                Button("") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .opacity(0)
            )
        }
        .frame(minWidth: 700, minHeight: 500)
        .frame(maxWidth: 950, maxHeight: 800)
    }
}

// MARK: - Window Controller
//
// IMPORTANT: NSWindow + SwiftUI Crash Prevention
// =============================================
// When using NSHostingController with NSWindow, crashes can occur during:
// 1. Window close animations (_NSWindowTransformAnimation dealloc)
// 2. Autorelease pool cleanup (__RELEASE_OBJECTS_IN_THE_ARRAY__)
// 3. Minimize animations
//
// Root cause: AppKit's window animation system retains references to views
// that may be deallocated by SwiftUI's memory management before the animation
// completes, causing EXC_BAD_ACCESS.
//
// Prevention measures implemented below:
// 1. Disable ALL window animations (animationBehavior = .none)
// 2. Set window.releasedWhenClosed = false to prevent premature deallocation
// 3. Keep strong references to both window AND hosting controller
// 4. Clear contentViewController BEFORE closing window
// 5. Use synchronous close (no animation callbacks)
// 6. Delay cleanup to next run loop to ensure AppKit is done with objects

class DefinitionsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var hostingController: NSHostingController<DefinitionsWindow>?

    func closeIfOpen() -> Bool {
        guard let w = window, w.isVisible else { return false }
        performSafeClose()
        return true
    }

    func show(words: [String: Int], foundWords: Set<String>, lexicon: Lexicon) {
        // Close existing window safely before creating new one
        if window != nil {
            performSafeClose()
        }

        let contentView = DefinitionsWindow(words: words, foundWords: foundWords, lexicon: lexicon)
        let hosting = NSHostingController(rootView: contentView)
        hostingController = hosting

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // CRASH PREVENTION: Disable all animations
        newWindow.animationBehavior = .none

        // CRASH PREVENTION: Don't auto-release window when closed
        // This prevents premature deallocation during autorelease pool drain
        newWindow.isReleasedWhenClosed = false

        newWindow.contentViewController = hosting
        newWindow.title = "Word Definitions"
        newWindow.delegate = self
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow
    }

    func close() {
        performSafeClose()
    }

    /// Safely closes the window without triggering crashes
    /// Order of operations is critical here
    private func performSafeClose() {
        guard let w = window else { return }

        // CRASH PREVENTION: Remove delegate first to prevent callbacks during close
        w.delegate = nil

        // CRASH PREVENTION: Clear content view controller BEFORE closing
        // This ensures SwiftUI views are properly cleaned up while window still exists
        w.contentViewController = nil

        // CRASH PREVENTION: Ensure no animations
        w.animationBehavior = .none

        // Close the window (synchronous, no animation)
        w.close()

        // CRASH PREVENTION: Delay clearing references to next run loop
        // This ensures AppKit has fully finished with these objects
        let windowToRelease = w
        let hostingToRelease = hostingController

        self.window = nil
        self.hostingController = nil

        // Keep references alive briefly to prevent premature deallocation
        DispatchQueue.main.async {
            _ = windowToRelease
            _ = hostingToRelease
        }
    }

    // NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        // Window is closing (user clicked X button)
        // Perform safe cleanup
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else { return }

        // Clear content before window fully closes
        closingWindow.contentViewController = nil

        // Delay reference cleanup
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
