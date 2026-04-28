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

    init(id: String, title: String, notes: String?, isCompleted: Bool, due: Date?,
         tags: [String], listId: String, listName: String, updated: Date?, completed: Date?) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.due = due
        self.tags = tags
        self.listId = listId
        self.listName = listName
        self.updated = updated
        self.completed = completed
    }
}
