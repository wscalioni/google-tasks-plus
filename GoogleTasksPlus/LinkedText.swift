import SwiftUI
import AppKit

struct LinkedText: View {
    let text: String
    let font: NSFont
    let color: Color
    let lineLimit: Int?

    init(_ text: String, font: Font = .system(size: 13), nsFont: NSFont = .systemFont(ofSize: 13), color: Color = DB.textSecondary, lineLimit: Int? = nil) {
        self.text = text
        self.font = nsFont
        self.color = color
        self.lineLimit = lineLimit
    }

    private static let urlPattern = try! NSRegularExpression(
        pattern: #"https?://[^\s<>\]\)]+"#,
        options: .caseInsensitive
    )

    private struct TextSegment: Identifiable {
        let id = UUID()
        let text: String
        let url: URL?
    }

    private var segments: [TextSegment] {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = Self.urlPattern.matches(in: text, range: range)

        if matches.isEmpty {
            return [TextSegment(text: text, url: nil)]
        }

        var result: [TextSegment] = []
        var lastEnd = 0

        for match in matches {
            let matchRange = match.range
            // Text before URL
            if matchRange.location > lastEnd {
                let plain = nsText.substring(with: NSRange(location: lastEnd, length: matchRange.location - lastEnd))
                result.append(TextSegment(text: plain, url: nil))
            }
            // The URL
            let urlString = nsText.substring(with: matchRange)
            result.append(TextSegment(text: urlString, url: URL(string: urlString)))
            lastEnd = matchRange.location + matchRange.length
        }

        // Text after last URL
        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd)
            result.append(TextSegment(text: remaining, url: nil))
        }

        return result
    }

    var body: some View {
        let built = segments.reduce(Text("")) { result, segment in
            if let url = segment.url {
                return result + Text(.init("[\(segment.text)](\(url.absoluteString))"))
                    .underline()
            } else {
                return result + Text(segment.text)
            }
        }

        built
            .font(.init(font))
            .foregroundColor(color)
            .lineLimit(lineLimit)
            .environment(\.openURL, OpenURLAction { url in
                NSWorkspace.shared.open(url)
                return .handled
            })
    }
}
