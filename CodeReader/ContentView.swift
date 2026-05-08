import SwiftUI
import UniformTypeIdentifiers

private let markdownType: UTType = UTType(filenameExtension: "md") ?? .plainText

struct ContentView: View {
    @StateObject private var recentFileStore = RecentFileStore()
    @State private var isImporterPresented = false
    @State private var openedFile: OpenedFile?
    @State private var isEditing = false
    @State private var showSaveSuccess = false
    @State private var loadError: String?
    @State private var fontSize: CGFloat = 14

    var body: some View {
        NavigationStack {
            Group {
                if openedFile != nil {
                    FileViewer(
                        openedFile: Binding(
                            get: { openedFile! },
                            set: { openedFile = $0 }
                        ),
                        isEditing: $isEditing,
                        fontSize: $fontSize,
                        onFinishEditing: saveCurrentFile
                    )
                } else {
                    emptyStateView
                }
            }
            .toolbar {
                if openedFile != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            returnToInitialPage()
                        } label: {
                            Label("返回", systemImage: "chevron.backward")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("打开文件", systemImage: "folder")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            fontSize = max(10, fontSize - 1)
                        } label: {
                            Image(systemName: "textformat.size.smaller")
                        }

                        Button {
                            fontSize = min(40, fontSize + 1)
                        } label: {
                            Image(systemName: "textformat.size.larger")
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [
                    .sourceCode,
                    markdownType,   // ✅ 专门为 .md 准备的类型
                    .text,
                    .plainText      // 兜底：其它纯文本
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .onOpenURL { url in
                openFile(at: url)
            }
            .alert("保存成功", isPresented: $showSaveSuccess) {
                Button("好的", role: .cancel) { }
            }
            .alert("错误", isPresented: .constant(loadError != nil)) {
                Button("知道了") { loadError = nil }
            } message: {
                Text(loadError ?? "")
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            loadError = error.localizedDescription

        case .success(let urls):
            guard let url = urls.first else { return }
            openFile(at: url)
        }
    }

    private func openFile(at url: URL) {
        Task.detached(priority: .userInitiated) {
            // ⬇️ 关键：申请访问安全作用域资源
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let kind = detectFileKind(for: url)
                await MainActor.run {
                    openedFile = OpenedFile(url: url, content: text, kind: kind)
                    isEditing = false
                    recentFileStore.add(url: url)
                }
            } catch {
                await MainActor.run {
                    loadError = "无法读取文件：\(error.localizedDescription)"
                }
            }
        }
    }

    private func saveCurrentFile() {
        guard let file = openedFile else { return }
        let accessGranted = file.url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                file.url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try file.content.write(to: file.url, atomically: true, encoding: .utf8)
            showSaveSuccess = true
        } catch {
            loadError = "保存失败：\(error.localizedDescription)"
        }
    }

    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 52))
                        .foregroundStyle(.tint)
                    Text("打开一个代码文件或 Markdown 文件")
                        .font(.headline)
                    Text("支持主流代码格式和 .md，先做一个轻量的代码阅读器和 Markdown 查看器。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                if !recentFileStore.files.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("最近打开")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(recentFileStore.files) { recentFile in
                            Button {
                                openRecentFile(recentFile)
                            } label: {
                                RecentFileRow(recentFile: recentFile)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
    }

    private func openRecentFile(_ recentFile: RecentFile) {
        do {
            let url = try recentFileStore.resolve(recentFile)
            openFile(at: url)
        } catch {
            recentFileStore.remove(recentFile)
            loadError = "无法重新打开最近文件：\(error.localizedDescription)"
        }
    }

    private func returnToInitialPage() {
        openedFile = nil
        isEditing = false
        showSaveSuccess = false
        loadError = nil
    }
}

private struct RecentFileRow: View {
    let recentFile: RecentFile

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(recentFile.displayName)
                    .font(.body)
                    .lineLimit(1)

                Text(recentFile.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .contentShape(Rectangle())
    }
}
