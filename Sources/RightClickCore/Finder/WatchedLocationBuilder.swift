import Foundation

public enum WatchedLocationBuilder {
    public static func build(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        rootURL: URL = URL(fileURLWithPath: "/", isDirectory: true),
        existingVolumeURLs: [URL] = mountedVolumeRoots(),
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> [URL] {
        var ordered: [URL] = [
            rootURL,
            homeDirectory,
            homeDirectory.appendingPathComponent("Desktop", isDirectory: true),
            homeDirectory.appendingPathComponent("Documents", isDirectory: true),
            homeDirectory.appendingPathComponent("Downloads", isDirectory: true),
            homeDirectory.appendingPathComponent("Library/Mobile Documents", isDirectory: true),
            homeDirectory.appendingPathComponent("Library/CloudStorage", isDirectory: true),
            URL(fileURLWithPath: "/Volumes", isDirectory: true),
        ]
        ordered.append(contentsOf: existingVolumeURLs)

        var seen = Set<URL>()
        var result: [URL] = []

        for url in ordered {
            let normalized = url.standardizedFileURL
            guard !seen.contains(normalized), fileExists(normalized) else {
                continue
            }

            seen.insert(normalized)
            result.append(normalized)
        }

        return result
    }

    @usableFromInline
    static func mountedVolumeRoots() -> [URL] {
        let volumes = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: volumes,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }
}
