import SwiftUI
import UIKit

struct SyntaxHighlightedText: View {
    let text: String
    let language: String
    let fontSize: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var highlighter = SyntaxHighlighter()
    @State private var attributed: AttributedString = AttributedString("")

    var body: some View {
        Text(attributed)
            .font(.system(size: fontSize, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear(perform: refresh)
            .onChange(of: text) { _ in refresh() }
            .onChange(of: language) { _ in refresh() }
            .onChange(of: colorScheme) { _ in refresh() }
            .onChange(of: fontSize) { _ in refresh() }
    }

    private func refresh() {
        let theme = SyntaxHighlightTheme.atomOne(for: colorScheme)
        attributed = highlighter.highlight(
            text: text,
            language: language,
            fontSize: fontSize,
            theme: theme
        )
    }
}

private final class SyntaxHighlighter: ObservableObject {
    private static let cache = NSCache<NSString, NSAttributedString>()
    private static let tokenCache = NSCache<NSString, HighlightTokenCacheValue>()

    func highlight(text: String, language: String, fontSize: CGFloat, theme: SyntaxHighlightTheme) -> AttributedString {
        let finalKey = cacheKey(text: text, language: language, fontSize: fontSize, themeKey: theme.cacheKey)
        if let cached = Self.cache.object(forKey: finalKey) {
            return AttributedString(cached)
        }

        let tokens = tokenizedMatches(text: text, language: language)
        let highlighted = buildHighlightedString(
            text: text,
            tokens: tokens,
            fontSize: fontSize,
            theme: theme
        )

        Self.cache.setObject(highlighted, forKey: finalKey)
        return AttributedString(highlighted)
    }

    private func tokenizedMatches(text: String, language: String) -> HighlightTokenCacheValue {
        let tokenKey = NSString(string: "\(language)|\(text.hashValue)")
        if let cachedTokens = Self.tokenCache.object(forKey: tokenKey) {
            return cachedTokens
        }

        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        let keywordRanges: [NSRange]
        if let regex = RegexStore.keywordRegex(for: language) {
            keywordRanges = regex.matches(in: text, range: fullRange).map { $0.range }
        } else {
            keywordRanges = []
        }

        let stringRanges = RegexStore.stringRegex.matches(in: text, range: fullRange).map { $0.range }
        let numberRanges = RegexStore.numberRegex.matches(in: text, range: fullRange).map { $0.range }

        let commentRanges: [NSRange]
        if let regex = RegexStore.commentRegex(for: language) {
            commentRanges = regex.matches(in: text, range: fullRange).map { $0.range }
        } else {
            commentRanges = []
        }

        var headingRanges: [NSRange] = []
        var boldRanges: [NSRange] = []
        var inlineCodeRanges: [NSRange] = []
        var linkRanges: [NSRange] = []
        if language == "md" || language == "markdown" {
            headingRanges = RegexStore.markdownHeadingRegex.matches(in: text, range: fullRange).map { $0.range }
            boldRanges = RegexStore.markdownBoldRegex.matches(in: text, range: fullRange).map { $0.range }
            inlineCodeRanges = RegexStore.markdownInlineCodeRegex.matches(in: text, range: fullRange).map { $0.range }
            linkRanges = RegexStore.markdownLinkRegex.matches(in: text, range: fullRange).map { $0.range }
        }

        let tokens = HighlightTokenCacheValue(
            keywordRanges: keywordRanges,
            stringRanges: stringRanges,
            numberRanges: numberRanges,
            commentRanges: commentRanges,
            headingRanges: headingRanges,
            boldRanges: boldRanges,
            inlineCodeRanges: inlineCodeRanges,
            linkRanges: linkRanges
        )

        Self.tokenCache.setObject(tokens, forKey: tokenKey)
        return tokens
    }

    private func buildHighlightedString(
        text: String,
        tokens: HighlightTokenCacheValue,
        fontSize: CGFloat,
        theme: SyntaxHighlightTheme
    ) -> NSAttributedString {
        let mutable = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.addAttribute(.foregroundColor, value: theme.plain, range: fullRange)

        let keywordColor = theme.keyword
        let stringColor = theme.string
        let commentColor = theme.comment
        let numberColor = theme.number
        let titleColor = theme.heading
        let emphasisColor = theme.emphasis
        let linkColor = theme.link

        for range in tokens.keywordRanges {
            mutable.addAttribute(.foregroundColor, value: keywordColor, range: range)
        }

        for range in tokens.stringRanges {
            mutable.addAttribute(.foregroundColor, value: stringColor, range: range)
        }

        for range in tokens.numberRanges {
            mutable.addAttribute(.foregroundColor, value: numberColor, range: range)
        }

        for range in tokens.commentRanges {
            mutable.addAttribute(.foregroundColor, value: commentColor, range: range)
        }

        for range in tokens.headingRanges {
            mutable.addAttribute(.foregroundColor, value: titleColor, range: range)
            mutable.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize + 2), range: range)
        }

        for range in tokens.boldRanges {
            mutable.addAttribute(.foregroundColor, value: emphasisColor, range: range)
            mutable.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize), range: range)
        }

        for range in tokens.inlineCodeRanges {
            mutable.addAttribute(.foregroundColor, value: stringColor, range: range)
            mutable.addAttribute(.backgroundColor, value: theme.inlineCodeBackground, range: range)
        }

        for range in tokens.linkRanges {
            mutable.addAttribute(.foregroundColor, value: linkColor, range: range)
            mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }

        return mutable
    }

    private func cacheKey(text: String, language: String, fontSize: CGFloat, themeKey: String) -> NSString {
        NSString(string: "\(language)|\(text.hashValue)|\(fontSize)|\(themeKey)")
    }
}

private final class HighlightTokenCacheValue: NSObject {
    let keywordRanges: [NSRange]
    let stringRanges: [NSRange]
    let numberRanges: [NSRange]
    let commentRanges: [NSRange]
    let headingRanges: [NSRange]
    let boldRanges: [NSRange]
    let inlineCodeRanges: [NSRange]
    let linkRanges: [NSRange]

    init(
        keywordRanges: [NSRange],
        stringRanges: [NSRange],
        numberRanges: [NSRange],
        commentRanges: [NSRange],
        headingRanges: [NSRange],
        boldRanges: [NSRange],
        inlineCodeRanges: [NSRange],
        linkRanges: [NSRange]
    ) {
        self.keywordRanges = keywordRanges
        self.stringRanges = stringRanges
        self.numberRanges = numberRanges
        self.commentRanges = commentRanges
        self.headingRanges = headingRanges
        self.boldRanges = boldRanges
        self.inlineCodeRanges = inlineCodeRanges
        self.linkRanges = linkRanges
    }
}

private enum RegexStore {
    private static var keywordRegexCache: [String: NSRegularExpression] = [:]

    static let stringRegex = try! NSRegularExpression(pattern: #"\".*?\"|'.*?'"#)
    static let numberRegex = try! NSRegularExpression(pattern: #"\b[0-9]+(\.[0-9]+)?\b"#)
    static let swiftCommentRegex = try! NSRegularExpression(pattern: #"//.*"#)
    static let cStyleCommentRegex = try! NSRegularExpression(pattern: #"//.*"#)
    static let pythonCommentRegex = try! NSRegularExpression(pattern: #"#.*"#)
    static let markdownHeadingRegex = try! NSRegularExpression(pattern: #"(?m)^#{1,6} .*"#)
    static let markdownBoldRegex = try! NSRegularExpression(pattern: #"(\*\*|__)(.+?)(\*\*|__)"#)
    static let markdownInlineCodeRegex = try! NSRegularExpression(pattern: #"`[^`]+`"#)
    static let markdownLinkRegex = try! NSRegularExpression(pattern: #"\[[^\]]+\]\([^\)]+\)"#)

    static func keywordRegex(for language: String) -> NSRegularExpression? {
        if let cached = keywordRegexCache[language] {
            return cached
        }

        let keywords: [String]
        switch language {
        case "swift":
            keywords = [
                "func", "let", "var", "if", "else", "for", "while", "struct", "class",
                "enum", "import", "return", "guard", "extension", "protocol", "init",
                "deinit", "where", "associatedtype"
            ]
        case "c", "cpp", "h", "hpp":
            keywords = [
                "int", "long", "short", "void", "char", "double", "float", "if", "else",
                "for", "while", "return", "struct", "class", "namespace", "using",
                "include", "define", "auto", "template"
            ]
        case "py":
            keywords = [
                "def", "class", "import", "from", "return", "if", "else", "elif",
                "for", "while", "in", "and", "or", "not", "with", "as"
            ]
        default:
            keywords = []
        }

        guard !keywords.isEmpty else { return nil }

        let pattern = #"\b(?:"# + keywords.joined(separator: "|") + #")\b"#
        let regex = try? NSRegularExpression(pattern: pattern)
        keywordRegexCache[language] = regex
        return regex
    }

    static func commentRegex(for language: String) -> NSRegularExpression? {
        switch language {
        case "swift":
            return swiftCommentRegex
        case "c", "cpp", "h", "hpp":
            return cStyleCommentRegex
        case "py":
            return pythonCommentRegex
        default:
            return nil
        }
    }
}

private struct SyntaxHighlightTheme {
    let plain: UIColor
    let keyword: UIColor
    let string: UIColor
    let comment: UIColor
    let number: UIColor
    let heading: UIColor
    let emphasis: UIColor
    let link: UIColor
    let inlineCodeBackground: UIColor
    let cacheKey: String

    static func atomOne(for scheme: ColorScheme) -> SyntaxHighlightTheme {
        switch scheme {
        case .dark:
            return SyntaxHighlightTheme(
                plain: UIColor(red: 0.67, green: 0.69, blue: 0.75, alpha: 1.0),           // #abb2bf
                keyword: UIColor(red: 0.78, green: 0.47, blue: 0.87, alpha: 1.0),        // #c678dd
                string: UIColor(red: 0.60, green: 0.77, blue: 0.48, alpha: 1.0),         // #98c379
                comment: UIColor(red: 0.36, green: 0.39, blue: 0.44, alpha: 1.0),        // #5c6370
                number: UIColor(red: 0.82, green: 0.60, blue: 0.40, alpha: 1.0),         // #d19a66
                heading: UIColor(red: 0.88, green: 0.42, blue: 0.46, alpha: 1.0),        // #e06c75
                emphasis: UIColor(red: 0.88, green: 0.42, blue: 0.46, alpha: 1.0),       // #e06c75
                link: UIColor(red: 0.38, green: 0.69, blue: 0.94, alpha: 1.0),           // #61afef
                inlineCodeBackground: UIColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1.0), // #282c34
                cacheKey: "atomOne-dark"
            )
        default:
            return SyntaxHighlightTheme(
                plain: UIColor(red: 0.22, green: 0.23, blue: 0.26, alpha: 1.0),          // #383a42
                keyword: UIColor(red: 0.65, green: 0.15, blue: 0.64, alpha: 1.0),        // #a626a4
                string: UIColor(red: 0.31, green: 0.63, blue: 0.31, alpha: 1.0),         // #50a14f
                comment: UIColor(red: 0.63, green: 0.63, blue: 0.65, alpha: 1.0),        // #a0a1a7
                number: UIColor(red: 0.60, green: 0.41, blue: 0.01, alpha: 1.0),         // #986801
                heading: UIColor(red: 0.89, green: 0.34, blue: 0.31, alpha: 1.0),        // #e45649
                emphasis: UIColor(red: 0.89, green: 0.34, blue: 0.31, alpha: 1.0),       // #e45649
                link: UIColor(red: 0.25, green: 0.47, blue: 0.95, alpha: 1.0),           // #4078f2
                inlineCodeBackground: UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0), // #ebebeb
                cacheKey: "atomOne-light"
            )
        }
    }
}
