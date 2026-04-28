import Foundation
import GRDB

enum SyncStatusIndicator {
    case idle, syncing, error(String)
}

@MainActor
class GoogleTasksService: ObservableObject {
    @Published var taskLists: [GoogleTaskList] = []
    @Published var allTasks: [TaskItem] = []
    @Published var allTags: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var syncStatus: SyncStatusIndicator = .idle

    private let db = DatabaseManager.shared
    private var taskListsObserver: AnyDatabaseCancellable?
    private var tasksObserver: AnyDatabaseCancellable?
    private var hasStartedObserving = false

    // MARK: - Start Observing (called once on auth)

    func startObserving(authService: GoogleAuthService) {
        guard !hasStartedObserving else { return }
        hasStartedObserving = true

        // Show loading only if DB is empty (first launch)
        let existingTasks = (try? db.fetchAllTasks()) ?? []
        isLoading = existingTasks.isEmpty

        // Subscribe to task lists from DB
        taskListsObserver = db.observeAllTaskLists()
            .start(in: db.pool, scheduling: .immediate) { [weak self] error in
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                }
            } onChange: { [weak self] records in
                Task { @MainActor in
                    self?.taskLists = records.map { $0.toGoogleTaskList() }
                    self?.rebuildTaskItems()
                }
            }

        // Subscribe to tasks from DB
        tasksObserver = db.observeAllTasks()
            .start(in: db.pool, scheduling: .immediate) { [weak self] error in
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                }
            } onChange: { [weak self] records in
                Task { @MainActor in
                    guard let self else { return }
                    self.cachedTaskRecords = records
                    self.rebuildTaskItems()
                    self.isLoading = false
                }
            }

        // Start sync engine
        Task {
            await SyncEngine.shared.configure(authService: authService)
            await SyncEngine.shared.triggerSync()
        }
    }

    private var cachedTaskRecords: [TaskRecord] = []

    private func rebuildTaskItems() {
        let listTitleById = Dictionary(uniqueKeysWithValues: taskLists.map { ($0.id, $0.title) })
        allTasks = cachedTaskRecords
            .compactMap { record -> TaskItem? in
                guard let listName = listTitleById[record.listId] else { return nil }
                return record.toTaskItem(listName: listName)
            }
            .sorted { ($0.updated ?? .distantPast) > ($1.updated ?? .distantPast) }
        allTags = computeAllTags()
    }

    // MARK: - Fetch All (now triggers sync)

    func fetchAll(authService: GoogleAuthService) async {
        if !hasStartedObserving {
            startObserving(authService: authService)
            return
        }
        syncStatus = .syncing
        await SyncEngine.shared.triggerSync()
        syncStatus = .idle
    }

    // MARK: - Toggle Task (local-first)

    func toggleTask(_ task: TaskItem, authService: GoogleAuthService) {
        let newStatus = task.isCompleted ? "needsAction" : "completed"
        let now = TaskRecord.nowISO8601()
        let record = TaskRecord(
            id: task.id,
            listId: task.listId,
            title: task.title,
            notes: task.notes,
            status: newStatus,
            due: task.due.map { ISO8601DateFormatter().string(from: $0) },
            updated: task.updated.map { ISO8601DateFormatter().string(from: $0) },
            completed: task.isCompleted ? nil : now,
            syncStatus: .pendingUpdate,
            localUpdated: now
        )
        try? db.upsertTask(record)
    }

    // MARK: - Create Task (local-first)

    func createTask(title: String, notes: String?, listId: String, due: String?, authService: GoogleAuthService) async -> Bool {
        let tempId = UUID().uuidString
        let now = TaskRecord.nowISO8601()
        let record = TaskRecord(
            id: tempId,
            listId: listId,
            title: title,
            notes: notes,
            status: "needsAction",
            due: due,
            syncStatus: .pendingCreate,
            localUpdated: now
        )
        do {
            try db.upsertTask(record)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Update Task (local-first)

    func updateTask(task: TaskItem, title: String, notes: String?, due: String?, authService: GoogleAuthService) async -> Bool {
        let now = TaskRecord.nowISO8601()
        let record = TaskRecord(
            id: task.id,
            listId: task.listId,
            title: title,
            notes: notes,
            status: task.isCompleted ? "completed" : "needsAction",
            due: due,
            updated: task.updated.map { ISO8601DateFormatter().string(from: $0) },
            completed: task.completed.map { ISO8601DateFormatter().string(from: $0) },
            syncStatus: .pendingUpdate,
            localUpdated: now
        )
        do {
            try db.upsertTask(record)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Move Task (local-first: delete old + create new)

    func moveTask(task: TaskItem, toListId: String, title: String, notes: String?, due: String?, authService: GoogleAuthService) async -> Bool {
        let now = TaskRecord.nowISO8601()

        // Mark old task for deletion
        let deleteRecord = TaskRecord(
            id: task.id,
            listId: task.listId,
            title: task.title,
            notes: task.notes,
            status: task.isCompleted ? "completed" : "needsAction",
            due: task.due.map { ISO8601DateFormatter().string(from: $0) },
            syncStatus: .pendingDelete,
            localUpdated: now
        )

        // Create new task in target list
        let newRecord = TaskRecord(
            id: UUID().uuidString,
            listId: toListId,
            title: title,
            notes: notes,
            status: "needsAction",
            due: due,
            syncStatus: .pendingCreate,
            localUpdated: now
        )

        do {
            try db.upsertTask(deleteRecord)
            try db.upsertTask(newRecord)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Create List (local-first)

    func createList(title: String) -> Bool {
        let record = TaskListRecord(
            id: UUID().uuidString,
            title: title,
            syncStatus: .pendingCreate
        )
        do {
            try db.upsertTaskList(record)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers

    private func computeAllTags() -> [String] {
        var tagCounts: [String: Int] = [:]
        for task in allTasks {
            for tag in task.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        return tagCounts.sorted { $0.value > $1.value }.map(\.key)
    }
}
