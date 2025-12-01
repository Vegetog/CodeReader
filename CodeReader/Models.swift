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

func detectFileKind(for url: URL) -> OpenedFileKind {
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
