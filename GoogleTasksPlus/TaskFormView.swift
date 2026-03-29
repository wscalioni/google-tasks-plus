import SwiftUI

struct TaskFormView: View {
    @EnvironmentObject var tasksService: GoogleTasksService

    let mode: Mode
    @Binding var title: String
    @Binding var notes: String
    @Binding var selectedListId: String
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    @Binding var selectedTags: Set<String>

    let updatedDate: Date?
    let completedDate: Date?

    @State private var newTagText = ""

    enum Mode { case create, edit }

    var allAvailableTags: [String] {
        var tags = tasksService.allTags
        for tag in selectedTags {
            if !tags.contains(tag) {
                tags.append(tag)
            }
        }
        return tags.sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Title
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DB.textSecondary)
                    TextField("Task title", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(DB.surface)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DB.border, lineWidth: 1)
                        )
                }

                // Task List
                VStack(alignment: .leading, spacing: 6) {
                    Text("List")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DB.textSecondary)
                    Picker("", selection: $selectedListId) {
                        ForEach(tasksService.taskLists) { list in
                            Text(list.title).tag(list.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                // Due Date
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $hasDueDate) {
                        Text("Due date")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DB.textSecondary)
                    }
                    .toggleStyle(.checkbox)

                    if hasDueDate {
                        DatePicker("", selection: $dueDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.field)
                    }
                }

                // Description
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DB.textSecondary)
                    TextEditor(text: $notes)
                        .font(.system(size: 13))
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(6)
                        .background(DB.surface)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DB.border, lineWidth: 1)
                        )
                }

                // Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DB.textSecondary)

                    if !allAvailableTags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(allAvailableTags, id: \.self) { tag in
                                TagChip(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag),
                                    action: {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    }
                                )
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text("#")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DB.textSecondary)
                            TextField("new-tag", text: $newTagText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .onSubmit { addNewTag() }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(DB.surface)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DB.border, lineWidth: 1)
                        )

                        Button(action: addNewTag) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(newTagText.isEmpty ? DB.textSecondary.opacity(0.4) : DB.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(newTagText.isEmpty)
                    }
                }

                // Metadata (edit mode only)
                if mode == .edit {
                    VStack(alignment: .leading, spacing: 6) {
                        Divider()
                        if let updated = updatedDate {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                Text("Updated: \(formatFullDateTime(updated))")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(DB.textSecondary)
                        }
                        if let completed = completedDate {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 11))
                                Text("Completed: \(formatFullDateTime(completed))")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(DB.success)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func addNewTag() {
        let tag = newTagText
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "#", with: "")
        guard !tag.isEmpty else { return }
        selectedTags.insert(tag)
        newTagText = ""
    }

    private func formatFullDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}
