import Foundation

actor SyncEngine {
    static let shared = SyncEngine()

    private weak var authService: GoogleAuthService?
    private var periodicTask: Task<Void, Never>?
    private var isSyncing = false

    private static let syncInterval: TimeInterval = 120 // 2 minutes

    func configure(authService: GoogleAuthService) {
        self.authService = authService
        startPeriodicSync()
    }

    func stop() {
        periodicTask?.cancel()
        periodicTask = nil
    }

    func triggerSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        await fullSync()
    }

    // MARK: - Periodic Sync

    private func startPeriodicSync() {
        periodicTask?.cancel()
        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.syncInterval))
                guard !Task.isCancelled else { break }
                await self?.fullSync()
            }
        }
    }

    // MARK: - Full Sync Cycle

    private func fullSync() async {
        await pushPendingChanges()
        await pullRemoteChanges()
    }

    // MARK: - Push Local Changes to API

    private func pushPendingChanges() async {
        guard let token = await authService?.getValidToken() else { return }
        let db = DatabaseManager.shared

        // Push list creates
        if let listCreates = try? db.fetchTaskLists(withSyncStatus: .pendingCreate) {
            for list in listCreates {
                await pushCreateList(list: list, token: token)
            }
        }

        // Push creates
        if let creates = try? db.fetchTasks(withSyncStatus: .pendingCreate) {
            for task in creates {
                await pushCreate(task: task, token: token)
            }
        }

        // Push updates
        if let updates = try? db.fetchTasks(withSyncStatus: .pendingUpdate) {
            for task in updates {
                await pushUpdate(task: task, token: token)
            }
        }

        // Push deletes
        if let deletes = try? db.fetchTasks(withSyncStatus: .pendingDelete) {
            for task in deletes {
                await pushDelete(task: task, token: token)
            }
        }
    }

    private func pushCreateList(list: TaskListRecord, token: String) async {
        let url = URL(string: "\(Config.tasksBaseURL)/users/@me/lists")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.quotaProject, forHTTPHeaderField: "x-goog-user-project")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["title": list.title]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if let created = try? JSONDecoder().decode(GoogleTaskList.self, from: data) {
                    let db = DatabaseManager.shared
                    try? db.deleteTaskList(id: list.id)
                    var newRecord = TaskListRecord(from: created)
                    newRecord.syncStatus = .synced
                    try? db.upsertTaskList(newRecord)
                }
            }
        } catch {
            // Network error — will retry next cycle
        }
    }

    private func pushCreate(task: TaskRecord, token: String) async {
        let url = URL(string: "\(Config.tasksBaseURL)/lists/\(task.listId)/tasks")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.quotaProject, forHTTPHeaderField: "x-goog-user-project")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["title": task.title]
        if let notes = task.notes, !notes.isEmpty { body["notes"] = notes }
        if let due = task.due { body["due"] = due }
        if task.status == "completed" { body["status"] = "completed" }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if let created = try? JSONDecoder().decode(GoogleTask.self, from: data) {
                    try? DatabaseManager.shared.markTaskSynced(
                        id: task.id,
                        newId: created.id,
                        apiUpdated: created.updated
                    )
                }
            }
            // On failure, leave as pending_create for retry
        } catch {
            // Network error — will retry next cycle
        }
    }

    private func pushUpdate(task: TaskRecord, token: String) async {
        let url = URL(string: "\(Config.tasksBaseURL)/lists/\(task.listId)/tasks/\(task.id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.quotaProject, forHTTPHeaderField: "x-goog-user-project")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["id": task.id, "title": task.title, "status": task.status]
        if let notes = task.notes { body["notes"] = notes }
        if let due = task.due { body["due"] = due }
        if let completed = task.completed { body["completed"] = completed }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    if let updated = try? JSONDecoder().decode(GoogleTask.self, from: data) {
                        try? DatabaseManager.shared.markTaskSynced(
                            id: task.id,
                            apiUpdated: updated.updated
                        )
                    }
                } else if http.statusCode == 404 {
                    // Task was deleted remotely — re-create
                    var createRecord = task
                    createRecord.syncStatus = .pendingCreate
                    createRecord.id = UUID().uuidString
                    try? DatabaseManager.shared.deleteTask(id: task.id)
                    try? DatabaseManager.shared.upsertTask(createRecord)
                }
            }
        } catch {
            // Network error — will retry next cycle
        }
    }

    private func pushDelete(task: TaskRecord, token: String) async {
        let url = URL(string: "\(Config.tasksBaseURL)/lists/\(task.listId)/tasks/\(task.id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.quotaProject, forHTTPHeaderField: "x-goog-user-project")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               http.statusCode == 204 || http.statusCode == 200 || http.statusCode == 404 {
                // Success or already gone — remove from local DB
                try? DatabaseManager.shared.deleteTask(id: task.id)
            }
        } catch {
            // Network error — will retry next cycle
        }
    }

    // MARK: - Pull Remote Changes

    private func pullRemoteChanges() async {
        guard let token = await authService?.getValidToken() else { return }
        let db = DatabaseManager.shared

        do {
            // Fetch all lists from API
            let listsURL = URL(string: "\(Config.tasksBaseURL)/users/@me/lists?maxResults=100")!
            let listsData = try await authorizedRequest(url: listsURL, token: token)
            let listsResponse = try JSONDecoder().decode(GoogleTaskListsResponse.self, from: listsData)
            let remoteLists = listsResponse.items ?? []

            // Fetch all tasks from API
            var allRemoteTasks: [TaskRecord] = []
            var listRecords: [TaskListRecord] = []

            for list in remoteLists {
                let listRecord = TaskListRecord(from: list)
                listRecords.append(listRecord)

                let tasks = try await fetchTasksForList(listId: list.id, token: token)
                let taskRecords = tasks.map { TaskRecord(from: $0, listId: list.id) }
                allRemoteTasks.append(contentsOf: taskRecords)
            }

            // Replace synced data with fresh remote data, preserving pending local changes
            try db.replaceAllData(lists: listRecords, tasks: allRemoteTasks)
        } catch {
            // Network or parse error — skip this pull cycle
        }
    }

    private func fetchTasksForList(listId: String, token: String) async throws -> [GoogleTask] {
        var allItems: [GoogleTask] = []
        var pageToken: String?

        repeat {
            var urlStr = "\(Config.tasksBaseURL)/lists/\(listId)/tasks?maxResults=100&showCompleted=true&showHidden=true"
            if let pt = pageToken {
                urlStr += "&pageToken=\(pt)"
            }

            let url = URL(string: urlStr)!
            let data = try await authorizedRequest(url: url, token: token)
            let response = try JSONDecoder().decode(GoogleTasksResponse.self, from: data)
            allItems.append(contentsOf: response.items ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil

        return allItems
    }

    // MARK: - Helpers

    private func authorizedRequest(url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.quotaProject, forHTTPHeaderField: "x-goog-user-project")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw URLError(.userAuthenticationRequired)
        }
        return data
    }
}
