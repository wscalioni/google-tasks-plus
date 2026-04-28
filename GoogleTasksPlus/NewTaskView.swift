import SwiftUI

struct NewTaskView: View {
    @EnvironmentObject var authService: GoogleAuthService
    @EnvironmentObject var tasksService: GoogleTasksService
    @Binding var isPresented: Bool
    var duplicateFrom: TaskItem? = nil
    var preselectedListId: String? = nil

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedListId = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var selectedTags: Set<String> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var composedNotes: String {
        composeNotes(notes: notes, tags: selectedTags)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Task")
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
                mode: .create,
                title: $title,
                notes: $notes,
                selectedListId: $selectedListId,
                hasDueDate: $hasDueDate,
                dueDate: $dueDate,
                selectedTags: $selectedTags,
                updatedDate: nil,
                completedDate: nil
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
                        Text("Create Task")
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
        .frame(width: 480, height: 580)
        .onAppear {
            if let source = duplicateFrom {
                title = source.title
                notes = source.notesWithoutTags
                selectedListId = source.listId
                selectedTags = Set(source.tags)
                if let due = source.due {
                    hasDueDate = true
                    dueDate = due
                }
            } else if selectedListId.isEmpty {
                if let preselected = preselectedListId,
                   tasksService.taskLists.contains(where: { $0.id == preselected }) {
                    selectedListId = preselected
                } else if let first = tasksService.taskLists.first {
                    selectedListId = first.id
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            let dueString: String? = hasDueDate ? ISO8601DateFormatter().string(from: dueDate) : nil
            let success = await tasksService.createTask(
                title: title,
                notes: composedNotes.isEmpty ? nil : composedNotes,
                listId: selectedListId,
                due: dueString,
                authService: authService
            )
            isSaving = false
            if success {
                isPresented = false
            } else {
                errorMessage = tasksService.errorMessage ?? "Failed to create task"
            }
        }
    }
}
