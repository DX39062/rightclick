import Foundation
import ZIPFoundation

enum OpenXMLPackageWriter {
    static func write(entries: [String: String], to url: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            throw ActionError.writeFailed("Destination already exists: \(url.path)")
        }

        do {
            let archive = try Archive(url: url, accessMode: .create)
            for path in entries.keys.sorted() {
                let data = Data(entries[path]!.utf8)
                try archive.addEntry(
                    with: path,
                    type: .file,
                    uncompressedSize: Int64(data.count),
                    provider: { (position: Int64, size: Int) throws -> Data in
                        data.subdata(in: Int(position)..<Int(position) + size)
                    }
                )
            }
        } catch {
            try? fileManager.removeItem(at: url)
            throw ActionError.writeFailed(error.localizedDescription)
        }
    }
}
