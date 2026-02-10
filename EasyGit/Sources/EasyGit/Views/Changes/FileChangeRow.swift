import SwiftUI

struct FileChangeRow: View {
    let file: GitFileChange
    let isStaged: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Checkbox to stage/unstage
                Button(action: onToggle) {
                    Image(systemName: isStaged ? "checkmark.square.fill" : "square")
                        .font(.system(size: 12))
                        .foregroundStyle(isStaged ? Theme.primary : Theme.textTertiary)
                }
                .buttonStyle(.plain)

                // Status badge
                Text(file.status.label)
                    .font(Theme.smallFontMedium)
                    .foregroundStyle(Theme.badgeColor(for: file.status))
                    .frame(width: 16, height: 16)
                    .background(Theme.badgeColor(for: file.status).opacity(0.15), in: RoundedRectangle(cornerRadius: 3))

                // Full relative path
                Text(file.path)
                    .font(Theme.uiFont)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                isSelected
                    ? Theme.primary.opacity(0.15)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
