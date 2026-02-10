import SwiftUI

struct DiffLineView: View {
    let line: DiffLine
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Old line number
            Text(line.oldLineNumber.map { String($0) } ?? "")
                .frame(width: 40, alignment: .trailing)
                .font(Theme.monoFont)
                .foregroundStyle(Theme.lineNumberColor)
                .padding(.trailing, 4)

            // New line number
            Text(line.newLineNumber.map { String($0) } ?? "")
                .frame(width: 40, alignment: .trailing)
                .font(Theme.monoFont)
                .foregroundStyle(Theme.lineNumberColor)
                .padding(.trailing, 8)

            // Prefix character
            Text(prefix)
                .font(Theme.monoFont)
                .foregroundStyle(textColor)
                .frame(width: 12)

            // Content
            Text(line.content)
                .font(Theme.monoFont)
                .foregroundStyle(textColor)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 0.5)
        .padding(.horizontal, 4)
        .background(backgroundColor)
        .overlay(
            isSelected
                ? Theme.primary.opacity(0.25)
                : Color.clear
        )
    }

    private var prefix: String {
        switch line.type {
        case .addition: return "+"
        case .removal: return "-"
        case .header: return ""
        case .context: return " "
        }
    }

    private var textColor: Color {
        switch line.type {
        case .addition: return Theme.diffAddText
        case .removal: return Theme.diffRemoveText
        case .header: return Theme.primary
        case .context: return Theme.textSecondary
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .addition: return Theme.diffAddBG
        case .removal: return Theme.diffRemoveBG
        case .header: return Theme.hunkHeaderBG
        case .context: return .clear
        }
    }
}
