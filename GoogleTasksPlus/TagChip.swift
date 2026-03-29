import SwiftUI

struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("#\(tag)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : DB.tagText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? DB.red : DB.tagBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? DB.red : DB.tagBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ListFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? DB.red : DB.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? DB.red.opacity(0.08) : DB.background)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? DB.red.opacity(0.3) : DB.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
