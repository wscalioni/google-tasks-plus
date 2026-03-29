import Foundation

enum TagParser {

    // Matches standard hashtags: #word or #word-with-dashes or #word_underscores
    // Does NOT match inside URLs, email addresses, or hex colors like #FF3621
    private static let tagPattern = #"(?<!\S)#([a-zA-Z][a-zA-Z0-9_-]*)"#

    static func extractTags(from text: String?) -> [String] {
        guard let text = text else { return [] }
        guard let regex = try? NSRegularExpression(pattern: tagPattern) else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        var tags: [String] = []
        var seen = Set<String>()

        for match in matches {
            if let tagRange = Range(match.range(at: 1), in: text) {
                let tag = String(text[tagRange]).lowercased()
                if !seen.contains(tag) {
                    seen.insert(tag)
                    tags.append(tag)
                }
            }
        }
        return tags
    }

    static func stripTags(from text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: tagPattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }
}
