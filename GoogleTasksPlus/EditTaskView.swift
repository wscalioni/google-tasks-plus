import SwiftUI

struct EditTaskView: View {
    @EnvironmentObject var authService: GoogleAuthService
    @EnvironmentObject var tasksService: GoogleTasksService
    @Binding var isPresented: Bool
    let task: TaskItem

    @State private var title: String
    @State private var notes: String
    @State private var selectedListId: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var selectedTags: Set<String>
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(isPresented: Binding<Bool>, task: TaskItem) {
        self._isPresented = isPresented
        self.task = task
        self._title = State(initialValue: task.title)
        self._notes = State(initialValue: task.notesWithoutTags)
        self._selectedListId = State(initialValue: task.listId)
        self._hasDueDate = State(initialValue: task.due != nil)
        self._dueDate = State(initialValue: task.due ?? Date())
        self._selectedTags = State(initialValue: Set(task.tags))
    }

    var composedNotes: String {
        composeNotes(notes: notes, tags: selectedTags)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Task")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DB.textPrimary)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(DB.background)

            Divider()

            TaskFormView(
                mode: .edit,
                title: $title,
                notes: $notes,
                selectedListId: $selectedListId,
                hasDueDate: $hasDueDate,
                dueDate: $dueDate,
                selectedTags: $selectedTags,
                updatedDate: task.updated,
                completedDate: task.completed
            )

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(DB.red)
                    .padding(.horizontal, 20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                if !task.isCompleted {
                    Button(action: completeAndClose) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                            Text("Complete")
                        }
                        .foregroundColor(DB.success)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(DB.success.opacity(0.1))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DB.success.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
                Button(action: save) {
                    HStack(spacing: 6) {
                        if isSaving { ProgressView().controlSize(.small) }
                        Text("Save Changes")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(title.isEmpty ? DB.textSecondary : DB.red)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty || isSaving)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(DB.background)
        }
        .frame(width: 480, height: 620)
    }

    private func completeAndClose() {
        tasksService.toggleTask(task, authService: authService)
        isPresented = false
    }

    private func save() {
        let targetListId = selectedListId
        let listChanged = targetListId != task.listId
        isSaving = true
        errorMessage = nil
        Task {
            let dueString: String? = hasDueDate ? ISO8601DateFormatter().string(from: dueDate) : nil
            let notesValue = composedNotes.isEmpty ? nil : composedNotes

            let success: Bool
            if listChanged {
                success = await tasksService.moveTask(
                    task: task,
                    toListId: targetListId,
                    title: title,
                    notes: notesValue,
                    due: dueString,
                    authService: authService
                )
            } else {
                success = await tasksService.updateTask(
                    task: task,
                    title: title,
                    notes: notesValue,
                    due: dueString,
                    authService: authService
                )
            }

            isSaving = false
            if success {
                isPresented = false
            } else {
                errorMessage = tasksService.errorMessage ?? "Failed to update task"
            }
        }
    }
}
