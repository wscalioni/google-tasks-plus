import Foundation
import GRDB

// MARK: - Sync Status

enum SyncStatus: String, DatabaseValueConvertible, Codable, CaseIterable {
    case synced        = "synced"
    case pendingCreate = "pending_create"
    case pendingUpdate = "pending_update"
    case pendingDelete = "pending_delete"
}

// MARK: - Task List Record

struct TaskListRecord: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "task_lists"

    var id: String
    var title: String
    var updated: String?
    var syncStatus: SyncStatus

    enum CodingKeys: String, CodingKey {
        case id, title, updated
        case syncStatus = "sync_status"
    }

    init(id: String, title: String, updated: String? = nil, syncStatus: SyncStatus = .synced) {
        self.id = id
        self.title = title
        self.updated = updated
        self.syncStatus = syncStatus
    }

    init(from googleTaskList: GoogleTaskList) {
        self.id = googleTaskList.id
        self.title = googleTaskList.title
        self.updated = googleTaskList.updated
        self.syncStatus = .synced
    }

    func toGoogleTaskList() -> GoogleTaskList {
        GoogleTaskList(id: id, title: title, updated: updated)
    }
}

// MARK: - Task Record

struct TaskRecord: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "tasks"

    var id: String
    var listId: String
    var title: String
    var notes: String?
    var status: String          // "needsAction" or "completed"
    var due: String?
    var updated: String?
    var completed: String?
    var parent: String?
    var position: String?
    var syncStatus: SyncStatus
    var localUpdated: String

    enum CodingKeys: String, CodingKey {
        case id, title, notes, status, due, updated, completed, parent, position
        case listId = "list_id"
        case syncStatus = "sync_status"
        case localUpdated = "local_updated"
    }

    init(id: String, listId: String, title: String, notes: String? = nil,
         status: String = "needsAction", due: String? = nil, updated: String? = nil,
         completed: String? = nil, parent: String? = nil, position: String? = nil,
         syncStatus: SyncStatus = .synced, localUpdated: String? = nil) {
        self.id = id
        self.listId = listId
        self.title = title
        self.notes = notes
        self.status = status
        self.due = due
        self.updated = updated
        self.completed = completed
        self.parent = parent
        self.position = position
        self.syncStatus = syncStatus
        self.localUpdated = localUpdated ?? Self.nowISO8601()
    }

    init(from googleTask: GoogleTask, listId: String) {
        self.id = googleTask.id
        self.listId = listId
        self.title = googleTask.title
        self.notes = googleTask.notes
        self.status = googleTask.status ?? "needsAction"
        self.due = googleTask.due
        self.updated = googleTask.updated
        self.completed = googleTask.completed
        self.parent = googleTask.parent
        self.position = googleTask.position
        self.syncStatus = .synced
        self.localUpdated = googleTask.updated ?? Self.nowISO8601()
    }

    func toTaskItem(listName: String) -> TaskItem {
        let isCompleted = status == "completed"
        return TaskItem(
            id: id,
            title: title,
            notes: notes,
            isCompleted: isCompleted,
            due: Self.parseDate(due),
            tags: TagParser.extractTags(from: notes),
            listId: listId,
            listName: listName,
            updated: Self.parseDate(updated),
            completed: Self.parseDate(completed)
        )
    }

    // MARK: - Date Helpers

    static func nowISO8601() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterBasic: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()

    static func parseDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        return isoFormatter.date(from: string) ?? isoFormatterBasic.date(from: string)
    }
}
