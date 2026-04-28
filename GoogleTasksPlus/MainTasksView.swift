import SwiftUI

struct MainTasksView: View {
    @EnvironmentObject var authService: GoogleAuthService
    @EnvironmentObject var tasksService: GoogleTasksService

    @State private var searchText = ""
    @State private var selectedTags: Set<String> = []
    @State private var selectedList: String? = nil
    @State private var showCompleted = false
    @State private var showingProfile = false
    @State private var showingNewTask = false
    @State private var duplicatingTask: TaskItem? = nil
    @State private var editingTask: TaskItem? = nil
    @State private var sortField: SortField = .date
    @State private var sortAscending = false
    @State private var recentlyCompletedIds: Set<String> = []
    @State private var showingNewList = false
    @State private var newListName = ""

    enum SortField: String, CaseIterable {
        case date = "Date"
        case name = "Name"
    }

    var filteredTasks: [TaskItem] {
        var tasks = tasksService.allTasks

        if let listId = selectedList {
            tasks = tasks.filter { $0.listId == listId }
        }

        if !showCompleted {
            tasks = tasks.filter { !$0.isCompleted || recentlyCompletedIds.contains($0.id) }
        }

        if !selectedTags.isEmpty {
            tasks = tasks.filter { task in
                !selectedTags.isDisjoint(with: Set(task.tags))
            }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            if query.hasPrefix("#") {
                let tagQuery = String(query.dropFirst())
                tasks = tasks.filter { task in
                    task.tags.contains { $0.contains(tagQuery) }
                }
            } else {
                tasks = tasks.filter { task in
                    task.title.lowercased().contains(query) ||
                    (task.notes?.lowercased().contains(query) ?? false) ||
                    task.tags.contains { $0.contains(query) }
                }
            }
        }

        switch sortField {
        case .date:
            tasks.sort {
                let a = $0.updated ?? .distantPast
                let b = $1.updated ?? .distantPast
                return sortAscending ? a < b : a > b
            }
        case .name:
            tasks.sort {
                let result = $0.title.localizedCaseInsensitiveCompare($1.title)
                return sortAscending ? result == .orderedAscending : result == .orderedDescending
            }
        }

        return tasks
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // List filter
            listFilterBar

            // Tag filter chips
            if !tasksService.allTags.isEmpty {
                tagFilterBar
            }

            Divider()

            // Content
            if tasksService.isLoading && tasksService.allTasks.isEmpty {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Spacer()
            } else if filteredTasks.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .background(DB.surface)
        .task {
            await tasksService.fetchAll(authService: authService)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileSheet(showingProfile: $showingProfile)
                .frame(width: 360, height: 320)
        }
        .sheet(isPresented: $showingNewTask) {
            NewTaskView(isPresented: $showingNewTask, preselectedListId: selectedList)
        }
        .sheet(item: $duplicatingTask) { task in
            NewTaskView(isPresented: Binding(
                get: { duplicatingTask != nil },
                set: { if !$0 { duplicatingTask = nil } }
            ), duplicateFrom: task)
        }
        .sheet(item: $editingTask) { task in
            EditTaskView(isPresented: Binding(
                get: { editingTask != nil },
                set: { if !$0 { editingTask = nil } }
            ), task: task)
        }
        .alert("New List", isPresented: $showingNewList) {
            TextField("List name", text: $newListName)
            Button("Cancel", role: .cancel) { newListName = "" }
            Button("Create") {
                let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    _ = tasksService.createList(title: name)
                }
                newListName = ""
            }
        } message: {
            Text("Enter a name for the new task list.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tasks+")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(DB.textPrimary)

                    Text("\(filteredTasks.count) tasks")
                        .font(.system(size: 12))
                        .foregroundColor(DB.textSecondary)
                }

                Spacer()

                // New Task
                Button(action: { showingNewTask = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("New Task")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DB.red)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: .command)

                // New List
                Button(action: { showingNewList = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 12, weight: .bold))
                        Text("New List")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(DB.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DB.background)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DB.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut("l", modifiers: .command)

                // Sort
                Menu {
                    Section("Sort by") {
                        ForEach(SortField.allCases, id: \.self) { field in
                            Button(action: { sortField = field }) {
                                HStack {
                                    Text(field.rawValue)
                                    if sortField == field {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    Divider()
                    Section("Order") {
                        Button(action: { sortAscending = true }) {
                            HStack {
                                Text(sortField == .date ? "Oldest first" : "A → Z")
                                if sortAscending { Image(systemName: "checkmark") }
                            }
                        }
                        Button(action: { sortAscending = false }) {
                            HStack {
                                Text(sortField == .date ? "Newest first" : "Z → A")
                                if !sortAscending { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                        Text(sortField.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(DB.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DB.background)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DB.border, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                // Completed toggle
                Button(action: { showCompleted.toggle() }) {
                    Image(systemName: showCompleted ? "eye.fill" : "eye.slash")
                        .font(.system(size: 14))
                        .foregroundColor(showCompleted ? DB.red : DB.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(DB.background)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DB.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(showCompleted ? "Hide completed tasks" : "Show completed tasks")

                // Refresh
                Button(action: {
                    Task { await tasksService.fetchAll(authService: authService) }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(DB.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(DB.background)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DB.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Refresh tasks")
                .keyboardShortcut("r", modifiers: .command)

                // Profile
                Button(action: { showingProfile = true }) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DB.navBackground)
                }
                .buttonStyle(.plain)
            }

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DB.textSecondary)
                    .font(.system(size: 14))

                TextField("Search tasks or #tags...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(DB.textPrimary)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DB.textSecondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(DB.background)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DB.border, lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(DB.background)
    }

    // MARK: - Tag Filter Bar

    private var tagFilterBar: some View {
        FlowLayout(spacing: 8) {
            ForEach(tasksService.allTags, id: \.self) { tag in
                TagChip(
                    tag: tag,
                    isSelected: selectedTags.contains(tag),
                    action: { toggleTag(tag) }
                )
            }

            if !selectedTags.isEmpty {
                Button(action: { selectedTags.removeAll() }) {
                    Text("Clear")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DB.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DB.background)
    }

    // MARK: - List Filter Bar

    private func incompleteTasks(forListId listId: String?) -> Int {
        let tasks = tasksService.allTasks.filter { !$0.isCompleted }
        if let listId = listId {
            return tasks.filter { $0.listId == listId }.count
        }
        return tasks.count
    }

    private var listFilterBar: some View {
        FlowLayout(spacing: 8) {
            ListFilterChip(
                title: "All Lists",
                count: incompleteTasks(forListId: nil),
                isSelected: selectedList == nil,
                action: { selectedList = nil }
            )

            ForEach(tasksService.taskLists) { list in
                ListFilterChip(
                    title: list.title,
                    count: incompleteTasks(forListId: list.id),
                    isSelected: selectedList == list.id,
                    action: { selectedList = selectedList == list.id ? nil : list.id }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DB.surface)
    }

    // MARK: - Task List

    private var taskListView: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(filteredTasks) { task in
                    TaskRowView(
                        task: task,
                        isDismissing: recentlyCompletedIds.contains(task.id),
                        taskLists: tasksService.taskLists,
                        onToggle: { completeTask(task) },
                        onTagTap: { tag in toggleTag(tag) },
                        onMoveToList: { listId in moveTask(task, toListId: listId) },
                        onDuplicate: { duplicatingTask = task }
                    )
                    .simultaneousGesture(TapGesture(count: 2).onEnded {
                        editingTask = task
                    })
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(DB.textSecondary.opacity(0.5))
            Text(searchText.isEmpty && selectedTags.isEmpty ? "No tasks found" : "No matching tasks")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(DB.textSecondary)
            if !selectedTags.isEmpty || !searchText.isEmpty {
                Button("Clear filters") {
                    searchText = ""
                    selectedTags.removeAll()
                }
                .font(.system(size: 13))
                .foregroundColor(DB.red)
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func moveTask(_ task: TaskItem, toListId: String) {
        Task {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dueString = task.due.map { isoFormatter.string(from: $0) }
            _ = await tasksService.moveTask(
                task: task,
                toListId: toListId,
                title: task.title,
                notes: task.notes,
                due: dueString,
                authService: authService
            )
        }
    }

    private func completeTask(_ task: TaskItem) {
        let wasCompleted = task.isCompleted
        tasksService.toggleTask(task, authService: authService)
        if !wasCompleted {
            recentlyCompletedIds.insert(task.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.35)) {
                    _ = recentlyCompletedIds.remove(task.id)
                }
            }
        }
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
}
