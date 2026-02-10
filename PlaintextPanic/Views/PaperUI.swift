import SwiftUI

// MARK: - Shared Paper UI Components
// Reusable components for the paper-feed aesthetic used by
// secondary windows (Definitions, About, Help, High Scores).

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

// MARK: - Multi-Row Paper Section

struct PaperRowMulti<Content: View>: View {
    let startIndex: Int
    let count: Int
    let content: () -> Content
    let lineHeight: CGFloat

    init(startIndex: Int, count: Int, lineHeight: CGFloat = 22, @ViewBuilder content: @escaping () -> Content) {
        self.startIndex = startIndex
        self.count = count
        self.lineHeight = lineHeight
        self.content = content
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left sprocket column
            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    SprocketHoleRow(rowIndex: startIndex + i, lineHeight: lineHeight)
                }
            }

            // Content area
            content()
                .frame(maxWidth: .infinity)
                .frame(height: CGFloat(count) * lineHeight)

            // Right sprocket column
            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    SprocketHoleRow(rowIndex: startIndex + i, lineHeight: lineHeight)
                }
            }
        }
        .frame(height: CGFloat(count) * lineHeight)
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

// MARK: - Reusable Content Row Views

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

// MARK: - Variable-Height Word Row with Sprockets

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
