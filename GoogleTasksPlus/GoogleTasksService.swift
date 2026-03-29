import Foundation

@MainActor
class GoogleTasksService: ObservableObject {
    @Published var taskLists: [GoogleTaskList] = []
    @Published var allTasks: [TaskItem] = []
    @Published var allTags: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Fetch all task lists and tasks

    func fetchAll(authService: GoogleAuthService) async {
        isLoading = true
        errorMessage = nil

        guard let token = await authService.getValidToken() else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        do {
            let listsURL = URL(string: "\(Config.tasksBaseURL)/users/@me/lists?maxResults=100")!
            let listsData = try await authorizedRequest(url: listsURL, token: token)
            let listsResponse = try JSONDecoder().decode(GoogleTaskListsResponse.self, from: listsData)
            self.taskLists = listsResponse.items ?? []

            var allItems: [TaskItem] = []
            for list in self.taskLists {
                let tasks = try await fetchTasksForList(listId: list.id, listName: list.title, token: token)
                allItems.append(contentsOf: tasks)
            }

            self.allTasks = allItems.sorted { ($0.updated ?? .distantPast) > ($1.updated ?? .distantPast) }
            self.allTags = computeAllTags()
        } catch {
            errorMessage = "Failed to load tasks: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Fetch tasks for a single list

    private func fetchTasksForList(listId: String, listName: String, token: String) async throws -> [TaskItem] {
        var allItems: [TaskItem] = []
        var pageToken: String?

        repeat {
            var urlStr = "\(Config.tasksBaseURL)/lists/\(listId)/tasks?maxResults=100&showCompleted=true&showHidden=true"
            if let pt = pageToken {
                urlStr += "&pageToken=\(pt)"
            }

            let url = URL(string: urlStr)!
            let data = try await authorizedRequest(url: url, token: token)
            let response = try JSONDecoder().decode(GoogleTasksResponse.self, from: data)

            let tasks = (response.items ?? []).map { TaskItem(from: $0, listId: listId, listName: listName) }
            allItems.append(contentsOf: tasks)
            pageToken = response.nextPageToken
        } while pageToken != nil

        return allItems
    }

    // MARK: - Toggle task completion

    func toggleTask(_ task: TaskItem, authService: GoogleAuthService) {
        // Optimistic update: flip status immediately in the UI
        if let index = allTasks.firstIndex(where: { $0.id == task.id }) {
            let old = allTasks[index]
            let toggled = TaskItem(toggling: old)
            allTasks[index] = toggled
            allTags = computeAllTags()
        }

        // Sync to Google Tasks API in the background
        Task {
            guard let token = await authService.getValidToken() else { return }

            let newStatus = task.isCompleted ? "needsAction" : "completed"
            let url = URL(string: "\(Config.tasksBaseURL)/lists/\(task.listId)/tasks/\(task.id)")!

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(Config.quotaProject, forHTTPHeaderField: "x-goog-user-project")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = ["id": task.id, "status": newStatus]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    // Revert on failure
                    await fetchAll(authService: authService)
                    errorMessage = "Failed to update task"
                }
            } catch {
                await fetchAll(authService: authService)
                errorMessage = "Failed to update task"
            }
        }
    }

    // MARK: - Update task

    func updateTask(task: TaskItem, title: String, notes: String?, due: String?, authService: GoogleAuthService) async -> Bool {
        guard let token = await authService.getValidToken() else {
            errorMessage = "Not authenticated"
            return false
        }

        let url = URL(string: "\(Config.tasksBaseURL)/lists/\(task.listId)/tasks/\(task.id)")!

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.quotaProject, forHTTPHeaderField: "x-goog-user-project")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["id": task.id, "title": title]
        body["notes"] = notes ?? ""
        if let due = due {
            body["due"] = due
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                await fetchAll(authService: authService)
                return true
            } else {
                errorMessage = "Failed to update task"
                return false
            }
        } catch {
            errorMessage = "Failed to update task: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Create task

    func createTask(title: String, notes: String?, listId: String, due: String?, authService: GoogleAuthService) async -> Bool {
        guard let token = await authService.getValidToken() else {
            errorMessage = "Not authenticated"
            return false
        }

        let url = URL(string: "\(Config.tasksBaseURL)/lists/\(listId)/tasks")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.quotaProject, forHTTPHeaderField: "x-goog-user-project")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["title": title]
        if let notes = notes, !notes.isEmpty { body["notes"] = notes }
        if let due = due { body["due"] = due }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                await fetchAll(authService: authService)
                return true
            } else {
                errorMessage = "Failed to create task"
                return false
            }
        } catch {
            errorMessage = "Failed to create task: \(error.localizedDescription)"
            return false
        }
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
