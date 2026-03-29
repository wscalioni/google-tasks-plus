import Foundation

func composeNotes(notes: String, tags: Set<String>) -> String {
    var result = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    if !tags.isEmpty {
        let tagLine = tags.sorted().map { "#\($0)" }.joined(separator: " ")
        if result.isEmpty {
            result = tagLine
        } else {
            result += "\n\n" + tagLine
        }
    }
    return result
}
