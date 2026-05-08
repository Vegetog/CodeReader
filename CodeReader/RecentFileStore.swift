import Foundation
import Combine

@MainActor
final class RecentFileStore: ObservableObject {
    @Published private(set) var files: [RecentFile] = []

    private let storageKey = "recentFiles"
    private let maxCount = 10

    init() {
        load()
    }

    func add(url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let recentFile = RecentFile(
                displayName: url.lastPathComponent,
                path: url.path,
                bookmarkData: bookmarkData,
                lastOpenedAt: Date()
            )

            files.removeAll { $0.path == recentFile.path }
            files.insert(recentFile, at: 0)

            if files.count > maxCount {
                files = Array(files.prefix(maxCount))
            }

            save()
        } catch {
            // If bookmark creation fails, avoid storing a recent item that cannot be reopened.
        }
    }

    func resolve(_ recentFile: RecentFile) throws -> URL {
        var isStale = false
        return try URL(
            resolvingBookmarkData: recentFile.bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    func remove(_ recentFile: RecentFile) {
        files.removeAll { $0.id == recentFile.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            files = []
            return
        }

        do {
            files = try JSONDecoder().decode([RecentFile].self, from: data)
        } catch {
            files = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(files)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
}
