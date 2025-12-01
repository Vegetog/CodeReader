import SwiftUI

struct FileViewer: View {
    @Binding var openedFile: OpenedFile
    @Binding var isEditing: Bool
    @Binding var fontSize: CGFloat

    @State private var markdownMode: MarkdownMode = .preview

    enum MarkdownMode: String, CaseIterable, Identifiable {
        case source = "源码"
        case preview = "预览"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            switch openedFile.kind {
            case .markdown:
                markdownView
            case .code(let lang):
                codeView(language: lang)
            case .plainText:
                plainTextView
            }
        }
        .animation(.default, value: isEditing)
        .animation(.default, value: markdownMode)
    }

    // MARK: - Code View

    private func codeView(language: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fileHeader {
                Text(language.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            }

            Divider()

            if isEditing {
                textEditorView
            } else {
                readOnlyScrollView {
                    SyntaxHighlightedText(
                        text: openedFile.content,
                        language: language,
                        fontSize: fontSize
                    )
                }
            }
        }
    }

    // MARK: - Markdown View

    private var markdownView: some View {
        VStack(alignment: .leading, spacing: 8) {
            fileHeader()

            Picker("模式", selection: $markdownMode) {
                ForEach(MarkdownMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Divider()

            Group {
                switch markdownMode {
                case .source:
                    if isEditing {
                        textEditorView
                    } else {
                        readOnlyScrollView {
                            SyntaxHighlightedText(
                                text: openedFile.content,
                                language: "markdown",
                                fontSize: fontSize
                            )
                        }
                    }
                case .preview:
                    MarkdownPreview(text: openedFile.content, fontSize: fontSize)
                }
            }
        }
    }

    // MARK: - Plain Text

    private var plainTextView: some View {
        VStack(alignment: .leading, spacing: 8) {
            fileHeader()

            Divider()

            if isEditing {
                textEditorView
            } else {
                readOnlyScrollView {
                    Text(openedFile.content)
                        .font(.system(size: fontSize, design: .monospaced))
                }
            }
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func fileHeader<Accessory: View>(@ViewBuilder accessory: () -> Accessory = { EmptyView() }) -> some View {
        HStack {
            Text(openedFile.url.lastPathComponent)
                .font(.headline)
            Spacer()
            accessory()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var textEditorView: some View {
        TextEditor(text: $openedFile.content)
            .font(.system(size: fontSize, design: .monospaced))
            .padding(.horizontal)
            .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func readOnlyScrollView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding()
                .textSelection(.enabled)
        }
    }
}
