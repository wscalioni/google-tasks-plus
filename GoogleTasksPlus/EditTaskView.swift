import SwiftUI

struct EditTaskView: View {
    @EnvironmentObject var authService: GoogleAuthService
    @EnvironmentObject var tasksService: GoogleTasksService
    @Binding var isPresented: Bool
    let task: TaskItem

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var selectedListId: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var selectedTags: Set<String> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

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
        .onAppear {
            title = task.title
            notes = task.notesWithoutTags
            selectedListId = task.listId
            hasDueDate = task.due != nil
            dueDate = task.due ?? Date()
            selectedTags = Set(task.tags)
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            let dueString: String? = hasDueDate ? ISO8601DateFormatter().string(from: dueDate) : nil
            let success = await tasksService.updateTask(
                task: task,
                title: title,
                notes: composedNotes.isEmpty ? nil : composedNotes,
                due: dueString,
                authService: authService
            )
            isSaving = false
            if success {
                isPresented = false
            } else {
                errorMessage = tasksService.errorMessage ?? "Failed to update task"
            }
        }
    }
}
