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
            HStack {
                Text(openedFile.url.lastPathComponent)
                    .font(.headline)
                Spacer()
                Text(language.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()

            if isEditing {
                TextEditor(text: $openedFile.content)
                    .font(.system(size: fontSize, design: .monospaced))
                    .padding(.horizontal)
                    .scrollContentBackground(.hidden)
            } else {
                ScrollView {
                    SyntaxHighlightedText(
                        text: openedFile.content,
                        language: language,
                        fontSize: fontSize
                    )
                    .padding()
                    .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Markdown View

    private var markdownView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(openedFile.url.lastPathComponent)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

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
                    TextEditor(text: $openedFile.content)
                        .font(.system(size: fontSize, design: .monospaced))
                        .padding(.horizontal)
                        .scrollContentBackground(.hidden)
                case .preview:
                    ScrollView {
                        MarkdownPreview(text: openedFile.content)
                            .padding()
                    }
                }
            }
        }
    }

    // MARK: - Plain Text

    private var plainTextView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(openedFile.url.lastPathComponent)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()

            if isEditing {
                TextEditor(text: $openedFile.content)
                    .font(.system(size: fontSize, design: .monospaced))
                    .padding(.horizontal)
                    .scrollContentBackground(.hidden)
            } else {
                ScrollView {
                    Text(openedFile.content)
                        .font(.system(size: fontSize, design: .monospaced))
                        .padding()
                        .textSelection(.enabled)
                }
            }
        }
    }
}
