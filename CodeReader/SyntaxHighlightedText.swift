import SwiftUI
import UIKit

struct SyntaxHighlightedText: View {
    let text: String
    let language: String
    let fontSize: CGFloat

    var body: some View {
        let attributed = highlight(text: text, language: language)
        Text(attributed)
            .font(.system(size: fontSize, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func highlight(text: String, language: String) -> AttributedString {
        let mutable = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: mutable.length)

        // 基础样式
        mutable.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)

        // 简单关键字
        let keywords: [String]
        switch language {
        case "swift":
            keywords = [
                "func", "let", "var", "if", "else", "for", "while", "struct", "class",
                "enum", "import", "return", "guard", "extension", "protocol"
            ]
        case "c", "cpp", "h", "hpp":
            keywords = [
                "int", "long", "short", "void", "char", "double", "float", "if", "else",
                "for", "while", "return", "struct", "class", "namespace", "using"
            ]
        case "py":
            keywords = [
                "def", "class", "import", "from", "return", "if", "else", "elif",
                "for", "while", "in", "and", "or", "not"
            ]
        default:
            keywords = []
        }

        let keywordColor = UIColor.systemBlue
        for kw in keywords {
            let pattern = "\\b\(kw)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: text, range: fullRange)
                for match in matches {
                    mutable.addAttribute(.foregroundColor, value: keywordColor, range: match.range)
                }
            }
        }

        // 字符串字面量
        if let stringRegex = try? NSRegularExpression(pattern: "\".*?\"", options: []) {
            let matches = stringRegex.matches(in: text, range: fullRange)
            for match in matches {
                mutable.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: match.range)
            }
        }

        // 注释
        if language == "swift" || language == "c" || language == "cpp" {
            if let commentRegex = try? NSRegularExpression(pattern: "//.*", options: []) {
                let matches = commentRegex.matches(in: text, range: fullRange)
                for match in matches {
                    mutable.addAttribute(.foregroundColor, value: UIColor.systemGray, range: match.range)
                }
            }
        }

        return AttributedString(mutable)
    }
}
