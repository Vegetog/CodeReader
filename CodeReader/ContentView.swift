import SwiftUI
import UniformTypeIdentifiers

private let markdownType: UTType = UTType(filenameExtension: "md") ?? .plainText

struct ContentView: View {
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
                        fontSize: $fontSize
                    )
                } else {
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
                    .padding()
                }
            }
            .navigationTitle("CodeReader")
            .toolbar {
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

                if openedFile != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            saveCurrentFile()
                        } label: {
                            Label("保存", systemImage: "square.and.arrow.down")
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [
                    .sourceCode,
                    markdownType,   // ✅ 专门为 .md 准备的类型
                    .plainText      // 兜底：其它纯文本
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
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
                openedFile = OpenedFile(url: url, content: text, kind: kind)
                isEditing = false
            } catch {
                loadError = "无法读取文件：\(error.localizedDescription)"
            }
        }
    }
    private func saveCurrentFile() {
        guard let file = openedFile else { return }
        do {
            try file.content.write(to: file.url, atomically: true, encoding: .utf8)
            showSaveSuccess = true
        } catch {
            loadError = "保存失败：\(error.localizedDescription)"
        }
    }
}
