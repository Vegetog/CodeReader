import SwiftUI
import UIKit

struct FileViewer: View {
    @Binding var openedFile: OpenedFile
    @Binding var isEditing: Bool
    @Binding var fontSize: CGFloat
    let onFinishEditing: () -> Void

    @State private var markdownMode: MarkdownMode = .preview
    @State private var isSearchVisible = false
    @State private var searchQuery = ""
    @State private var currentSearchIndex = 0
    @State private var isOutlinePresented = false
    @State private var scrollTargetLineNumber: Int?
    @State private var scrollTargetHeadingID: String?
    private let largeSourceThreshold = 50_000

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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if isEditing {
                        isEditing = false
                        onFinishEditing()
                    } else {
                        isEditing = true
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                }
                .disabled(isEditButtonDisabled)
                .accessibilityLabel(isEditing ? "完成" : "编辑")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if openedFile.kind == .markdown, markdownMode == .preview {
                        markdownMode = .source
                    }
                    isSearchVisible.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }

            if openedFile.kind == .markdown, !markdownHeadings.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isOutlinePresented = true
                    } label: {
                        Image(systemName: "list.bullet.indent")
                    }
                }
            }
        }
        .popover(isPresented: $isOutlinePresented) {
            MarkdownOutlineView(headings: markdownHeadings) { heading in
                jump(to: heading)
                isOutlinePresented = false
            }
        }
        .onChange(of: openedFile.kind) {
            markdownMode = .preview
        }
        .onChange(of: openedFile.url) {
            searchQuery = ""
            currentSearchIndex = 0
            scrollTargetLineNumber = nil
            scrollTargetHeadingID = nil
        }
        .onChange(of: searchQuery) {
            currentSearchIndex = 0
        }
        .onChange(of: searchMatches) {
            clampCurrentSearchIndex()
        }
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

            if isSearchVisible {
                searchBar
            }

            Divider()

            if isEditing {
                textEditorView
            } else {
                sourceReadOnlyView(language: language)
            }
        }
    }

    // MARK: - Markdown View

    private var markdownView: some View {
        VStack(alignment: .leading, spacing: 8) {
            fileHeader()

            if isSearchVisible {
                searchBar
            }

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
                        markdownSourceReadOnlyView
                    }
                case .preview:
                    MarkdownPreview(
                        text: openedFile.content,
                        fontSize: fontSize,
                        scrollTargetHeadingID: scrollTargetHeadingID
                    )
                }
            }
        }
    }

    // MARK: - Plain Text

    private var plainTextView: some View {
        VStack(alignment: .leading, spacing: 8) {
            fileHeader()

            if isSearchVisible {
                searchBar
            }

            Divider()

            if isEditing {
                textEditorView
            } else {
                sourceReadOnlyView(language: "text")
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

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索当前文件", text: $searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Text(searchSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .trailing)

            Button {
                moveToPreviousSearchMatch()
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(searchMatches.isEmpty)

            Button {
                moveToNextSearchMatch()
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(searchMatches.isEmpty)

            Button {
                searchQuery = ""
                isSearchVisible = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var textEditorView: some View {
        LineNumberedTextEditor(text: $openedFile.content, fontSize: fontSize)
    }

    private var markdownSourceReadOnlyView: some View {
        LineNumberedTextEditor(
            text: .constant(openedFile.content),
            fontSize: fontSize,
            isEditable: false,
            scrollTargetLineNumber: currentSearchMatch?.lineNumber ?? scrollTargetLineNumber
        )
    }

    @ViewBuilder
    private func sourceReadOnlyView(language: String) -> some View {
        if isLargeSource {
            VirtualizedSourceTextView(text: openedFile.content, fontSize: fontSize)
        } else {
            NumberedSourceScrollView(
                text: openedFile.content,
                language: language,
                fontSize: fontSize,
                searchMatches: searchMatches,
                currentSearchMatch: currentSearchMatch,
                scrollTargetLineNumber: scrollTargetLineNumber
            )
        }
    }

    private var isEditButtonDisabled: Bool {
        openedFile.kind == .markdown && markdownMode == .preview
    }

    private var isLargeSource: Bool {
        openedFile.content.utf8.count >= largeSourceThreshold
    }

    private var markdownHeadings: [MarkdownHeading] {
        guard openedFile.kind == .markdown else { return [] }
        return extractMarkdownHeadings(from: openedFile.content)
    }

    private var searchMatches: [SourceSearchMatch] {
        SourceSearch.matches(in: openedFile.content, query: searchQuery)
    }

    private var currentSearchMatch: SourceSearchMatch? {
        guard searchMatches.indices.contains(currentSearchIndex) else {
            return nil
        }

        return searchMatches[currentSearchIndex]
    }

    private var searchSummary: String {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "0/0"
        }

        guard !searchMatches.isEmpty else {
            return "0/0"
        }

        return "\(currentSearchIndex + 1)/\(searchMatches.count)"
    }

    private func moveToPreviousSearchMatch() {
        guard !searchMatches.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchMatches.count) % searchMatches.count
    }

    private func moveToNextSearchMatch() {
        guard !searchMatches.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchMatches.count
    }

    private func clampCurrentSearchIndex() {
        guard !searchMatches.isEmpty else {
            currentSearchIndex = 0
            return
        }

        currentSearchIndex = min(currentSearchIndex, searchMatches.count - 1)
    }

    private func jump(to heading: MarkdownHeading) {
        scrollTargetLineNumber = heading.lineNumber
        scrollTargetHeadingID = heading.id
    }
}

private struct MarkdownOutlineView: View {
    let headings: [MarkdownHeading]
    let onSelect: (MarkdownHeading) -> Void

    var body: some View {
        NavigationStack {
            List(headings) { heading in
                Button {
                    onSelect(heading)
                } label: {
                    HStack(spacing: 8) {
                        Text(String(repeating: "  ", count: max(0, heading.level - 1)) + heading.title)
                            .lineLimit(2)
                        Spacer()
                        Text("\(heading.lineNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct NumberedSourceScrollView: View {
    let text: String
    let language: String
    let fontSize: CGFloat
    let searchMatches: [SourceSearchMatch]
    let currentSearchMatch: SourceSearchMatch?
    let scrollTargetLineNumber: Int?

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(lines) { line in
                            SourceLineRow(
                                line: line,
                                language: language,
                                fontSize: fontSize,
                                gutterWidth: gutterWidth,
                                viewportWidth: geometry.size.width
                            )
                            .id(line.number)
                        }
                    }
                    .frame(minWidth: geometry.size.width, alignment: .leading)
                    .padding(.vertical, 8)
                }
                .textSelection(.enabled)
                .onChange(of: currentSearchMatch?.id) {
                    scrollToCurrentMatch(using: proxy)
                }
                .onChange(of: searchMatches) {
                    scrollToCurrentMatch(using: proxy)
                }
                .onChange(of: scrollTargetLineNumber) {
                    scrollToTargetLine(using: proxy)
                }
                .onAppear {
                    scrollToTargetLine(using: proxy)
                    scrollToCurrentMatch(using: proxy)
                }
            }
        }
    }

    private var lines: [SourceLine] {
        let matchesByLine = Dictionary(grouping: searchMatches, by: \.lineNumber)
        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let displayLines = rawLines.isEmpty ? [""] : rawLines.map(String.init)

        return displayLines.enumerated().map { offset, rawLine in
            let number = offset + 1
            let matches = matchesByLine[number] ?? []
            return SourceLine(
                number: number,
                text: rawLine,
                searchRanges: matches.map(\.range),
                currentSearchRange: currentSearchMatch?.lineNumber == number ? currentSearchMatch?.range : nil
            )
        }
    }

    private var gutterWidth: CGFloat {
        let lineCount = max(text.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
        return LineNumberLayout.gutterWidth(lineCount: lineCount, fontSize: fontSize)
    }

    private func scrollToCurrentMatch(using proxy: ScrollViewProxy) {
        guard let currentSearchMatch else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(currentSearchMatch.lineNumber, anchor: .center)
        }
    }

    private func scrollToTargetLine(using proxy: ScrollViewProxy) {
        guard let scrollTargetLineNumber else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(scrollTargetLineNumber, anchor: .center)
        }
    }
}

private struct SourceLine: Identifiable {
    var id: Int { number }

    let number: Int
    let text: String
    let searchRanges: [NSRange]
    let currentSearchRange: NSRange?
}

private struct SourceLineRow: View {
    let line: SourceLine
    let language: String
    let fontSize: CGFloat
    let gutterWidth: CGFloat
    let viewportWidth: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: LineNumberLayout.contentGap) {
            Text("\(line.number)")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: gutterWidth, alignment: .trailing)
                .textSelection(.disabled)

            SyntaxHighlightedText(
                text: line.text.isEmpty ? " " : line.text,
                language: language,
                fontSize: fontSize,
                searchRanges: line.searchRanges,
                currentSearchRange: line.currentSearchRange,
                wrapsLines: true
            )
            .frame(width: contentWidth, alignment: .leading)
        }
        .frame(width: viewportWidth, alignment: .leading)
        .padding(.leading, LineNumberLayout.leadingInset)
        .padding(.vertical, 1)
    }

    private var contentWidth: CGFloat {
        max(
            viewportWidth - LineNumberLayout.leadingInset - gutterWidth - LineNumberLayout.contentGap - LineNumberLayout.trailingInset,
            fontSize * 4
        )
    }
}

private enum LineNumberLayout {
    static let leadingInset: CGFloat = 4
    static let contentGap: CGFloat = 8
    static let trailingInset: CGFloat = 12

    static func gutterWidth(lineCount: Int, fontSize: CGFloat) -> CGFloat {
        let digits = max(String(max(lineCount, 1)).count, 1)
        return ceil(CGFloat(digits) * fontSize * 0.62 + 8)
    }
}

private struct VirtualizedSourceTextView: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat

    func makeUIView(context: Context) -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.estimatedRowHeight = 600
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(SourceChunkCell.self, forCellReuseIdentifier: SourceChunkCell.reuseIdentifier)
        context.coordinator.update(text: text, fontSize: fontSize, in: tableView)
        return tableView
    }

    func updateUIView(_ tableView: UITableView, context: Context) {
        context.coordinator.update(text: text, fontSize: fontSize, in: tableView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        private let linesPerChunk = 40
        private var chunks: [SourceChunk] = []
        private var textSignature = TextSignature()
        private var pendingSignature: TextSignature?
        private var fontSize: CGFloat = 14

        func update(text: String, fontSize: CGFloat, in tableView: UITableView) {
            let nextSignature = TextSignature(text: text)
            let textChanged = nextSignature != textSignature
            let fontChanged = self.fontSize != fontSize

            if textChanged {
                pendingSignature = nextSignature
                chunks = []
                tableView.reloadData()

                let linesPerChunk = linesPerChunk
                DispatchQueue.global(qos: .userInitiated).async {
                    let nextChunks = Self.makeChunks(for: text, linesPerChunk: linesPerChunk)

                    DispatchQueue.main.async { [weak self, weak tableView] in
                        guard let self, self.pendingSignature == nextSignature else {
                            return
                        }

                        self.chunks = nextChunks
                        self.textSignature = nextSignature
                        self.pendingSignature = nil
                        tableView?.reloadData()
                    }
                }
            }

            if fontChanged {
                self.fontSize = fontSize
            }

            if fontChanged {
                tableView.reloadData()
            }
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            if chunks.isEmpty && pendingSignature != nil {
                return 1
            }

            return chunks.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SourceChunkCell.reuseIdentifier,
                for: indexPath
            )

            guard let sourceCell = cell as? SourceChunkCell else {
                return cell
            }

            if chunks.isEmpty && pendingSignature != nil {
                sourceCell.configurePlaceholder(fontSize: fontSize)
                return sourceCell
            }

            sourceCell.configure(text: chunks[indexPath.row].displayText, fontSize: fontSize)
            return sourceCell
        }

        nonisolated private static func makeChunks(for text: String, linesPerChunk: Int) -> [SourceChunk] {
            guard !text.isEmpty else {
                return [SourceChunk(displayText: "1  ")]
            }

            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let numberWidth = max(String(lines.count).count, 1)
            var result: [SourceChunk] = []
            var chunkStart = 0

            while chunkStart < lines.count {
                let chunkEnd = min(chunkStart + linesPerChunk, lines.count)
                let displayText = (chunkStart..<chunkEnd)
                    .map { offset in
                        "\(Self.paddedLineNumber(offset + 1, width: numberWidth))  \(lines[offset])"
                    }
                    .joined(separator: "\n")

                result.append(SourceChunk(displayText: displayText))
                chunkStart = chunkEnd
            }

            return result
        }

        nonisolated private static func paddedLineNumber(_ lineNumber: Int, width: Int) -> String {
            let rawLineNumber = String(lineNumber)
            guard rawLineNumber.count < width else {
                return rawLineNumber
            }

            return String(repeating: " ", count: width - rawLineNumber.count) + rawLineNumber
        }
    }

    private struct SourceChunk {
        let displayText: String
    }

    private struct TextSignature: Equatable {
        var byteCount = 0
        var firstScalar: Unicode.Scalar?
        var lastScalar: Unicode.Scalar?

        init() { }

        init(text: String) {
            byteCount = text.utf8.count
            firstScalar = text.unicodeScalars.first
            lastScalar = text.unicodeScalars.last
        }
    }
}

private final class SourceChunkCell: UITableViewCell {
    static let reuseIdentifier = "SourceChunkCell"

    private let sourceLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        sourceLabel.numberOfLines = 0
        sourceLabel.lineBreakMode = .byCharWrapping
        sourceLabel.adjustsFontForContentSizeCategory = false
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(sourceLabel)
        NSLayoutConstraint.activate([
            sourceLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            sourceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            sourceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            sourceLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        sourceLabel.text = nil
    }

    func configurePlaceholder(fontSize: CGFloat) {
        sourceLabel.text = "正在准备源码..."
        sourceLabel.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        sourceLabel.textColor = .secondaryLabel
    }

    func configure(text: String, fontSize: CGFloat) {
        sourceLabel.text = text
        sourceLabel.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        sourceLabel.textColor = .label
    }
}

private struct LineNumberedTextEditor: UIViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    var isEditable = true
    var scrollTargetLineNumber: Int?

    func makeUIView(context: Context) -> LineNumberedTextEditorView {
        let view = LineNumberedTextEditorView()
        view.configure(text: text, fontSize: fontSize, isEditable: isEditable) { nextText in
            text = nextText
        }
        view.scrollToLine(scrollTargetLineNumber)
        return view
    }

    func updateUIView(_ view: LineNumberedTextEditorView, context: Context) {
        view.configure(text: text, fontSize: fontSize, isEditable: isEditable) { nextText in
            text = nextText
        }
        view.scrollToLine(scrollTargetLineNumber)
    }
}

private final class LineNumberedTextEditorView: UIView, UITextViewDelegate {
    private let gutterView = LineNumberGutterView()
    private let textView = UITextView()
    private var gutterWidthConstraint: NSLayoutConstraint?
    private var onTextChange: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        gutterView.backgroundColor = .clear
        gutterView.textView = textView

        textView.backgroundColor = .clear
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 12)
        textView.delegate = self

        gutterView.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(gutterView)
        addSubview(textView)

        let gutterWidthConstraint = gutterView.widthAnchor.constraint(equalToConstant: 28)
        self.gutterWidthConstraint = gutterWidthConstraint

        NSLayoutConstraint.activate([
            gutterView.topAnchor.constraint(equalTo: topAnchor),
            gutterView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gutterView.bottomAnchor.constraint(equalTo: bottomAnchor),
            gutterWidthConstraint,

            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: gutterView.trailingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(text: String, fontSize: CGFloat, isEditable: Bool, onTextChange: @escaping (String) -> Void) {
        self.onTextChange = onTextChange

        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if textView.font != font {
            textView.font = font
            gutterView.font = font
        }

        if textView.text != text {
            textView.text = text
        }

        textView.isEditable = isEditable
        textView.isSelectable = true

        let lineCount = max(text.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
        gutterWidthConstraint?.constant = LineNumberLayout.gutterWidth(lineCount: lineCount, fontSize: fontSize)
        gutterView.setNeedsDisplay()
    }

    func textViewDidChange(_ textView: UITextView) {
        onTextChange?(textView.text)
        gutterView.setNeedsDisplay()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        gutterView.setNeedsDisplay()
    }

    func scrollToLine(_ lineNumber: Int?) {
        guard let lineNumber, lineNumber > 0 else { return }

        let nsText = textView.text as NSString
        var currentLine = 1
        var targetLocation = 0

        while currentLine < lineNumber, targetLocation < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: targetLocation, length: 0))
            targetLocation = NSMaxRange(lineRange)
            currentLine += 1
        }

        guard targetLocation <= nsText.length else { return }

        textView.layoutManager.ensureLayout(for: textView.textContainer)
        let glyphIndex = textView.layoutManager.glyphIndexForCharacter(at: targetLocation)
        let lineRect = textView.layoutManager.lineFragmentRect(
            forGlyphAt: glyphIndex,
            effectiveRange: nil
        )
        let y = max(lineRect.minY + textView.textContainerInset.top - 24, -textView.adjustedContentInset.top)
        textView.setContentOffset(CGPoint(x: 0, y: y), animated: true)
        gutterView.setNeedsDisplay()
    }
}

private final class LineNumberGutterView: UIView {
    weak var textView: UITextView?
    var font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular) {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let textView, let text = textView.text, !text.isEmpty else {
            draw(lineNumber: 1, y: textView?.textContainerInset.top ?? 8)
            return
        }

        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        let visibleRect = CGRect(
            x: 0,
            y: textView.contentOffset.y,
            width: textView.bounds.width,
            height: textView.bounds.height
        )
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let nsText = text as NSString
        var glyphIndex = glyphRange.location

        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let sourceLineRange = nsText.lineRange(for: NSRange(location: characterIndex, length: 0))

            if characterIndex == sourceLineRange.location {
                let lineNumber = 1 + nsText.substring(to: sourceLineRange.location).filter(\.isNewline).count
                let y = lineRect.minY + textView.textContainerInset.top - textView.contentOffset.y
                draw(lineNumber: lineNumber, y: y)
            }

            glyphIndex = NSMaxRange(lineGlyphRange)
        }
    }

    private func draw(lineNumber: Int, y: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraph
        ]

        let drawingRect = CGRect(x: 0, y: y, width: bounds.width - 4, height: font.lineHeight)
        NSString(string: "\(lineNumber)").draw(in: drawingRect, withAttributes: attributes)
    }
}
