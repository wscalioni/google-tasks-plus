import SwiftUI
import AppKit

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
                    Menu {
                        ForEach(tasksService.taskLists) { list in
                            Button(action: { selectedListId = list.id }) {
                                HStack {
                                    Text(list.title)
                                    if selectedListId == list.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(tasksService.taskLists.first(where: { $0.id == selectedListId })?.title ?? "Select list")
                                .font(.system(size: 14))
                                .foregroundColor(DB.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11))
                                .foregroundColor(DB.textSecondary)
                        }
                        .padding(10)
                        .background(DB.surface)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DB.border, lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
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

                    if hasLinks(in: notes) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Links")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DB.textSecondary)
                            ForEach(extractURLs(from: notes), id: \.absoluteString) { url in
                                Button(action: { NSWorkspace.shared.open(url) }) {
                                    Text(url.absoluteString)
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                        .underline()
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    if hovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
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

    private static let urlPattern = try! NSRegularExpression(
        pattern: #"https?://[^\s<>\]\)]+"#,
        options: .caseInsensitive
    )

    private func hasLinks(in text: String) -> Bool {
        let range = NSRange(location: 0, length: (text as NSString).length)
        return Self.urlPattern.firstMatch(in: text, range: range) != nil
    }

    private func extractURLs(from text: String) -> [URL] {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = Self.urlPattern.matches(in: text, range: range)
        return matches.compactMap { match in
            URL(string: nsText.substring(with: match.range))
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
