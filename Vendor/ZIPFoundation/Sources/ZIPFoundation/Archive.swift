import Foundation

public enum AccessMode: Equatable {
    case create
    case read
}

public struct Entry {
    public enum EntryType {
        case file
    }

    public let path: String
    public let type: EntryType
}

public final class Archive: Sequence {
    private struct StoredEntry {
        let path: String
        let type: Entry.EntryType
        let data: Data
        let crc32: UInt32
    }

    private let url: URL
    private let accessMode: AccessMode
    private var storedEntries: [StoredEntry] = []

    public init?(url: URL, accessMode: AccessMode) {
        self.url = url
        self.accessMode = accessMode

        switch accessMode {
        case .create:
            do {
                try Data().write(to: url, options: .withoutOverwriting)
            } catch {
                return nil
            }
        case .read:
            do {
                storedEntries = try Self.readEntries(from: url)
            } catch {
                return nil
            }
        }
    }

    public func makeIterator() -> AnyIterator<Entry> {
        var iterator = storedEntries.makeIterator()
        return AnyIterator {
            guard let entry = iterator.next() else {
                return nil
            }
            return Entry(path: entry.path, type: entry.type)
        }
    }

    public func addEntry(
        with path: String,
        type: Entry.EntryType,
        uncompressedSize: UInt32,
        provider: (_ position: Int, _ size: Int) throws -> Data
    ) throws {
        guard accessMode == .create else {
            throw ArchiveError.invalidAccessMode
        }

        let data = try provider(0, Int(uncompressedSize))
        let entry = StoredEntry(path: path, type: type, data: data, crc32: Self.crc32(for: data))
        storedEntries.append(entry)
        try Self.writeArchive(storedEntries, to: url)
    }
}

private enum ArchiveError: Error {
    case invalidAccessMode
    case malformedArchive
}

private extension Archive {
    private static func readEntries(from url: URL) throws -> [StoredEntry] {
        let data = try Data(contentsOf: url)
        let eocdOffset = try endOfCentralDirectoryOffset(in: data)
        let totalEntries = Int(readUInt16(in: data, at: eocdOffset + 10))
        let centralDirectoryOffset = Int(readUInt32(in: data, at: eocdOffset + 16))
        var offset = centralDirectoryOffset
        var entries: [StoredEntry] = []

        for _ in 0..<totalEntries {
            guard readUInt32(in: data, at: offset) == 0x02014b50 else {
                throw ArchiveError.malformedArchive
            }

            let nameLength = Int(readUInt16(in: data, at: offset + 28))
            let extraLength = Int(readUInt16(in: data, at: offset + 30))
            let commentLength = Int(readUInt16(in: data, at: offset + 32))
            let compressedSize = Int(readUInt32(in: data, at: offset + 20))
            let uncompressedSize = Int(readUInt32(in: data, at: offset + 24))
            let pathData = data.subdata(in: offset + 46..<(offset + 46 + nameLength))
            let path = String(decoding: pathData, as: UTF8.self)

            entries.append(
                StoredEntry(
                    path: path,
                    type: .file,
                    data: Data(count: compressedSize),
                    crc32: readUInt32(in: data, at: offset + 16)
                )
            )

            _ = uncompressedSize
            offset += 46 + nameLength + extraLength + commentLength
        }

        return entries
    }

    private static func writeArchive(_ entries: [StoredEntry], to url: URL) throws {
        var archiveData = Data()
        var centralDirectory = Data()
        var localOffsets: [UInt32] = []

        for entry in entries {
            let localOffset = UInt32(archiveData.count)
            localOffsets.append(localOffset)

            let pathData = Data(entry.path.utf8)
            archiveData.appendUInt32(0x04034b50)
            archiveData.appendUInt16(20)
            archiveData.appendUInt16(0)
            archiveData.appendUInt16(0)
            archiveData.appendUInt16(0)
            archiveData.appendUInt16(0)
            archiveData.appendUInt32(entry.crc32)
            archiveData.appendUInt32(UInt32(entry.data.count))
            archiveData.appendUInt32(UInt32(entry.data.count))
            archiveData.appendUInt16(UInt16(pathData.count))
            archiveData.appendUInt16(0)
            archiveData.append(pathData)
            archiveData.append(entry.data)

            centralDirectory.appendUInt32(0x02014b50)
            centralDirectory.appendUInt16(20)
            centralDirectory.appendUInt16(20)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt32(entry.crc32)
            centralDirectory.appendUInt32(UInt32(entry.data.count))
            centralDirectory.appendUInt32(UInt32(entry.data.count))
            centralDirectory.appendUInt16(UInt16(pathData.count))
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt32(0)
            centralDirectory.appendUInt32(localOffset)
            centralDirectory.append(pathData)
        }

        let centralDirectoryOffset = UInt32(archiveData.count)
        archiveData.append(centralDirectory)
        archiveData.appendUInt32(0x06054b50)
        archiveData.appendUInt16(0)
        archiveData.appendUInt16(0)
        archiveData.appendUInt16(UInt16(entries.count))
        archiveData.appendUInt16(UInt16(entries.count))
        archiveData.appendUInt32(UInt32(centralDirectory.count))
        archiveData.appendUInt32(centralDirectoryOffset)
        archiveData.appendUInt16(0)

        try archiveData.write(to: url, options: .atomic)
    }

    static func endOfCentralDirectoryOffset(in data: Data) throws -> Int {
        guard data.count >= 22 else {
            throw ArchiveError.malformedArchive
        }

        let minimumOffset = Swift.max(0, data.count - (22 + 65535))
        for offset in stride(from: data.count - 22, through: minimumOffset, by: -1) {
            if readUInt32(in: data, at: offset) == 0x06054b50 {
                return offset
            }
        }

        throw ArchiveError.malformedArchive
    }

    static func readUInt16(in data: Data, at offset: Int) -> UInt16 {
        let range = offset..<(offset + 2)
        return data.subdata(in: range).withUnsafeBytes { rawBuffer in
            rawBuffer.load(as: UInt16.self)
        }.littleEndian
    }

    static func readUInt32(in data: Data, at offset: Int) -> UInt32 {
        let range = offset..<(offset + 4)
        return data.subdata(in: range).withUnsafeBytes { rawBuffer in
            rawBuffer.load(as: UInt32.self)
        }.littleEndian
    }

    static func crc32(for data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = crcTable[index] ^ (crc >> 8)
        }
        return crc ^ 0xffffffff
    }

    static let crcTable: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            if crc & 1 == 1 {
                crc = 0xedb88320 ^ (crc >> 1)
            } else {
                crc >>= 1
            }
        }
        return crc
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { buffer in
            append(buffer.bindMemory(to: UInt8.self))
        }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { buffer in
            append(buffer.bindMemory(to: UInt8.self))
        }
    }
}
