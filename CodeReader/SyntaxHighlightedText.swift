import SwiftUI
import UIKit

struct SyntaxHighlightedText: View {
    let text: String
    let language: String
    let fontSize: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = SyntaxHighlightTheme.atomOne(for: colorScheme)
        let attributed = highlight(text: text, language: language, theme: theme)
        Text(attributed)
            .font(.system(size: fontSize, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func highlight(text: String, language: String, theme: SyntaxHighlightTheme) -> AttributedString {
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
        case "md", "markdown":
            keywords = []
        default:
            keywords = []
        }

        for kw in keywords {
            let pattern = "\\b\(kw)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: text, range: fullRange)
                for match in matches {
                    mutable.addAttribute(.foregroundColor, value: keywordColor, range: match.range)
                }
            }
        }

        if let stringRegex = try? NSRegularExpression(pattern: "\".*?\"|'.*?'", options: []) {
            let matches = stringRegex.matches(in: text, range: fullRange)
            for match in matches {
                mutable.addAttribute(.foregroundColor, value: stringColor, range: match.range)
            }
        }

        if let numberRegex = try? NSRegularExpression(pattern: "\\b[0-9]+(\\.[0-9]+)?\\b", options: []) {
            let matches = numberRegex.matches(in: text, range: fullRange)
            for match in matches {
                mutable.addAttribute(.foregroundColor, value: numberColor, range: match.range)
            }
        }

        if ["swift", "c", "cpp", "h", "hpp"].contains(language) {
            if let commentRegex = try? NSRegularExpression(pattern: "//.*", options: []) {
                let matches = commentRegex.matches(in: text, range: fullRange)
                for match in matches {
                    mutable.addAttribute(.foregroundColor, value: commentColor, range: match.range)
                }
            }
        }

        if language == "py" {
            if let commentRegex = try? NSRegularExpression(pattern: "#.*", options: []) {
                let matches = commentRegex.matches(in: text, range: fullRange)
                for match in matches {
                    mutable.addAttribute(.foregroundColor, value: commentColor, range: match.range)
                }
            }
        }

        if language == "md" || language == "markdown" {
            if let headingRegex = try? NSRegularExpression(pattern: "(?m)^#{1,6} .*", options: []) {
                let matches = headingRegex.matches(in: text, range: fullRange)
                for match in matches {
                    mutable.addAttribute(.foregroundColor, value: titleColor, range: match.range)
                    mutable.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize + 2), range: match.range)
                }
            }

            if let boldRegex = try? NSRegularExpression(pattern: "(\*\*|__)(.+?)(\*\*|__)", options: []) {
                let matches = boldRegex.matches(in: text, range: fullRange)
                for match in matches {
                    mutable.addAttribute(.foregroundColor, value: emphasisColor, range: match.range)
                    mutable.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize), range: match.range)
                }
            }

            if let inlineCodeRegex = try? NSRegularExpression(pattern: "`[^`]+`", options: []) {
                let matches = inlineCodeRegex.matches(in: text, range: fullRange)
                for match in matches {
                    mutable.addAttribute(.foregroundColor, value: stringColor, range: match.range)
                    mutable.addAttribute(.backgroundColor, value: theme.inlineCodeBackground, range: match.range)
                }
            }

            if let linkRegex = try? NSRegularExpression(pattern: "\\[[^\\]]+\\]\\([^\\)]+\\)", options: []) {
                let matches = linkRegex.matches(in: text, range: fullRange)
                for match in matches {
                    mutable.addAttribute(.foregroundColor, value: linkColor, range: match.range)
                    mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                }
            }
        }

        return AttributedString(mutable)
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
                inlineCodeBackground: UIColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1.0) // #282c34
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
                inlineCodeBackground: UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0) // #ebebeb
            )
        }
    }
}
