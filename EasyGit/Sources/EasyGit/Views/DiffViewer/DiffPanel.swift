import SwiftUI

struct DiffPanel: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(DiffViewModel.self) private var diffVM
    @Environment(ChangesViewModel.self) private var changesVM: ChangesViewModel?

    @State private var dragOrigin: CGPoint?
    @State private var dragCurrent: CGPoint?

    private let lineHeight: CGFloat = 18
    private let contentPadding: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)

                Text(diffVM.filename.isEmpty ? "No file selected" : "Diff: \(diffVM.filename)")
                    .font(Theme.uiFontMedium)
                    .foregroundStyle(Theme.textSecondary)

                if !diffVM.selectedLineIDs.isEmpty {
                    Text("\(diffVM.selectedLineIDs.count) line\(diffVM.selectedLineIDs.count == 1 ? "" : "s") selected")
                        .font(Theme.smallFont)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.badgeBG, in: Capsule())
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.panelHeaderBG)

            Divider().background(Theme.borderColor)

            // Diff content
            if diffVM.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let diff = diffVM.currentDiff, !diff.isEmpty {
                let allLines = diff.hunks.flatMap(\.lines)

                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        // Diff lines
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(allLines) { line in
                                DiffLineView(
                                    line: line,
                                    isSelected: diffVM.selectedLineIDs.contains(line.id)
                                )
                                .frame(height: lineHeight)
                            }
                        }
                        .padding(contentPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Rubber band selection rectangle
                        if let rect = selectionRect {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.primary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .strokeBorder(Theme.primary.opacity(0.4), lineWidth: 1)
                                )
                                .frame(width: rect.width, height: rect.height)
                                .offset(x: rect.origin.x, y: rect.origin.y)
                                .allowsHitTesting(false)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 3, coordinateSpace: .local)
                            .onChanged { value in
                                dragOrigin = value.startLocation
                                dragCurrent = value.location
                                updateDragSelection(allLines: allLines)
                            }
                            .onEnded { _ in
                                dragOrigin = nil
                                dragCurrent = nil
                            }
                    )
                    .contextMenu {
                        if diffVM.canStageLines {
                            Button("Stage \(diffVM.selectedLineIDs.count) Line\(diffVM.selectedLineIDs.count == 1 ? "" : "s")") {
                                Task { await stageLines() }
                            }
                        }
                        if diffVM.canUnstageLines {
                            Button("Unstage \(diffVM.selectedLineIDs.count) Line\(diffVM.selectedLineIDs.count == 1 ? "" : "s")") {
                                Task { await unstageLines() }
                            }
                        }
                        if diffVM.selectedLineIDs.isEmpty {
                            Text("Drag to select lines, then right-click")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text(diffVM.filename.isEmpty ? "Select a file to view changes" : "No changes to display")
                        .font(Theme.uiFont)
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.diffBG)
    }

    // MARK: - Selection Rectangle

    private var selectionRect: CGRect? {
        guard let start = dragOrigin, let end = dragCurrent else { return nil }
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let w = abs(end.x - start.x)
        let h = abs(end.y - start.y)
        guard w > 2 || h > 2 else { return nil }
        return CGRect(x: x, y: y, width: max(w, 1), height: max(h, 1))
    }

    // MARK: - Drag Selection Logic

    private func updateDragSelection(allLines: [DiffLine]) {
        guard let start = dragOrigin, let end = dragCurrent else { return }
        let minY = min(start.y, end.y) - contentPadding
        let maxY = max(start.y, end.y) - contentPadding

        let startIdx = max(0, Int(floor(minY / lineHeight)))
        let endIdx = min(allLines.count - 1, Int(floor(maxY / lineHeight)))

        guard startIdx <= endIdx, startIdx < allLines.count else {
            diffVM.selectedLineIDs = []
            return
        }

        var selected = Set<UUID>()
        for i in startIdx...endIdx {
            let line = allLines[i]
            if line.type == .addition || line.type == .removal {
                selected.insert(line.id)
            }
        }
        diffVM.selectedLineIDs = selected
    }

    // MARK: - Stage / Unstage

    private func stageLines() async {
        do {
            try await diffVM.stageSelectedLines()
            await refreshAfterLineStage()
        } catch {
            await MainActor.run {
                appVM.errorMessage = "Stage lines failed: \(error.localizedDescription)"
            }
        }
    }

    private func unstageLines() async {
        do {
            try await diffVM.unstageSelectedLines()
            await refreshAfterLineStage()
        } catch {
            await MainActor.run {
                appVM.errorMessage = "Unstage lines failed: \(error.localizedDescription)"
            }
        }
    }

    private func refreshAfterLineStage() async {
        guard let repo = appVM.selectedRepo else { return }
        await changesVM?.refresh(repoPath: repo.path)
        if let file = changesVM?.selectedFile {
            let staged = changesVM?.selectedFileIsStaged ?? false
            await diffVM.loadDiff(repoPath: repo.path, file: file, staged: staged)
        }
    }
}
