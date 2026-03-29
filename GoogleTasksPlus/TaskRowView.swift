import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onTagTap: (String) -> Void

    @State private var isExpanded = false

    private var hasExpandableContent: Bool {
        !task.notesWithoutTags.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Checkbox
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(task.isCompleted ? DB.success : DB.textSecondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(task.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(task.isCompleted ? DB.textSecondary : DB.textPrimary)
                        .strikethrough(task.isCompleted, color: DB.textSecondary)
                        .lineLimit(isExpanded ? nil : 2)

                    // Notes
                    if !task.notesWithoutTags.isEmpty {
                        LinkedText(task.notesWithoutTags,
                                  nsFont: .systemFont(ofSize: 13),
                                  color: DB.textSecondary,
                                  lineLimit: isExpanded ? nil : 2)
                    }

                    // Tags
                    if !task.tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(task.tags, id: \.self) { tag in
                                Button(action: { onTagTap(tag) }) {
                                    Text("#\(tag)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(DB.tagText)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(DB.tagBackground)
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(DB.tagBorder, lineWidth: 0.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Metadata row
                    HStack(spacing: 12) {
                        Label(task.listName, systemImage: "list.bullet")
                            .font(.system(size: 11))
                            .foregroundColor(DB.textSecondary)

                        if let due = task.due {
                            Label(formatDate(due), systemImage: "calendar")
                                .font(.system(size: 11))
                                .foregroundColor(due < Date() && !task.isCompleted ? DB.red : DB.textSecondary)
                        }

                        if let updated = task.updated {
                            Label(formatDateTime(updated), systemImage: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(DB.textSecondary)
                        }

                        if task.isCompleted, let completed = task.completed {
                            Label(formatDateTime(completed), systemImage: "checkmark.circle")
                                .font(.system(size: 11))
                                .foregroundColor(DB.success)
                        }

                        Spacer()

                        // Expand/collapse button
                        if hasExpandableContent {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Text(isExpanded ? "Less" : "More")
                                        .font(.system(size: 11, weight: .medium))
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(DB.tagText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(DB.tagBackground)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .background(DB.background)
        .cornerRadius(10)
        .shadow(color: DB.cardShadow, radius: 2, y: 1)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today' h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d, h:mm a"
        } else {
            formatter.dateFormat = "MMM d yyyy, h:mm a"
        }
        return formatter.string(from: date)
    }
}
