import Foundation

enum OpenedFileKind: Equatable {
    case code(language: String)
    case markdown
    case plainText
}

struct OpenedFile: Equatable {
    var url: URL
    var content: String
    var kind: OpenedFileKind
}

nonisolated func detectFileKind(for url: URL) -> OpenedFileKind {
    let ext = url.pathExtension.lowercased()
    switch ext {
    case "md":
        return .markdown
    case "swift", "c", "cpp", "h", "hpp", "java", "py", "js", "ts", "kt", "rs", "go":
        return .code(language: ext)
    default:
        return .plainText
    }
}

struct RecentFile: Codable, Identifiable, Equatable {
    var id: String { path }

    let displayName: String
    let path: String
    let bookmarkData: Data
    let lastOpenedAt: Date
}

struct MarkdownHeading: Identifiable, Equatable {
    var id: String { "heading-\(ordinal)" }

    let ordinal: Int
    let level: Int
    let title: String
    let lineNumber: Int
}

struct SourceSearchMatch: Identifiable, Equatable {
    var id: Int { index }

    let index: Int
    let lineNumber: Int
    let range: NSRange
}

nonisolated func extractMarkdownHeadings(from text: String) -> [MarkdownHeading] {
    var ordinal = 0

    return text
        .split(separator: "\n", omittingEmptySubsequences: false)
        .enumerated()
        .compactMap { offset, line in
            let rawLine = String(line)
            guard rawLine.hasPrefix("#") else { return nil }

            let level = rawLine.prefix(while: { $0 == "#" }).count
            guard (1...6).contains(level) else { return nil }

            let titleStart = rawLine.index(rawLine.startIndex, offsetBy: level)
            guard titleStart < rawLine.endIndex, rawLine[titleStart] == " " else {
                return nil
            }

            let title = rawLine[titleStart...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }

            let heading = MarkdownHeading(ordinal: ordinal, level: level, title: title, lineNumber: offset + 1)
            ordinal += 1
            return heading
        }
}

enum SourceSearch {
    nonisolated static func matches(in text: String, query: String) -> [SourceSearchMatch] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        var result: [SourceSearchMatch] = []
        var matchIndex = 0

        for (lineOffset, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineText = String(line)
            let nsLine = lineText as NSString
            let queryLength = (trimmedQuery as NSString).length
            var searchRange = NSRange(location: 0, length: nsLine.length)

            while searchRange.length > 0 {
                let foundRange = nsLine.range(
                    of: trimmedQuery,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchRange
                )

                guard foundRange.location != NSNotFound else { break }

                result.append(
                    SourceSearchMatch(
                        index: matchIndex,
                        lineNumber: lineOffset + 1,
                        range: foundRange
                    )
                )
                matchIndex += 1

                let nextLocation = foundRange.location + max(foundRange.length, queryLength, 1)
                guard nextLocation <= nsLine.length else { break }
                searchRange = NSRange(location: nextLocation, length: nsLine.length - nextLocation)
            }
        }

        return result
    }
}
