import Foundation

// MARK: - Google Tasks API Response Models

struct GoogleTaskListsResponse: Codable {
    let kind: String?
    let items: [GoogleTaskList]?
}

struct GoogleTaskList: Codable, Identifiable {
    let id: String
    let title: String
    let updated: String?
}

struct GoogleTasksResponse: Codable {
    let kind: String?
    let items: [GoogleTask]?
    let nextPageToken: String?
}

struct GoogleTask: Codable, Identifiable {
    let id: String
    let title: String
    let notes: String?
    let status: String?       // "needsAction" or "completed"
    let due: String?
    let updated: String?
    let completed: String?
    let parent: String?
    let position: String?
    let links: [TaskLink]?

    struct TaskLink: Codable {
        let type: String?
        let description: String?
        let link: String?
    }
}

// MARK: - App Models

struct TaskItem: Identifiable {
    let id: String
    let title: String
    let notes: String?
    let isCompleted: Bool
    let due: Date?
    let tags: [String]
    let listId: String
    let listName: String
    let updated: Date?
    let completed: Date?

    var notesWithoutTags: String {
        guard let notes = notes else { return "" }
        return TagParser.stripTags(from: notes).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func parseDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        return isoFormatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    init(from googleTask: GoogleTask, listId: String, listName: String) {
        self.id = googleTask.id
        self.title = googleTask.title
        self.notes = googleTask.notes
        self.isCompleted = googleTask.status == "completed"
        self.listId = listId
        self.listName = listName
        self.tags = TagParser.extractTags(from: googleTask.notes)
        self.due = Self.parseDate(googleTask.due)
        self.updated = Self.parseDate(googleTask.updated)
        self.completed = Self.parseDate(googleTask.completed)
    }

    init(toggling other: TaskItem) {
        self.id = other.id
        self.title = other.title
        self.notes = other.notes
        self.isCompleted = !other.isCompleted
        self.due = other.due
        self.tags = other.tags
        self.listId = other.listId
        self.listName = other.listName
        self.updated = other.updated
        self.completed = other.isCompleted ? nil : Date()
    }
}
