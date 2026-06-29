import Foundation

public struct FinderActionRequest: Codable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public let context: FinderContext

    public init(id: UUID = UUID(), createdAt: Date = Date(), context: FinderContext) {
        self.id = id
        self.createdAt = createdAt
        self.context = context
    }
}

public struct ActionRequestStore {
    public static let defaultFileName = "latest-finder-action-request.json"
    public static let defaultDirectoryName = "RightClick"

    public static var defaultContainerDirectory: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return baseURL.appendingPathComponent(defaultDirectoryName, isDirectory: true)
    }

    private let containerDirectory: URL
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.init(containerDirectory: Self.defaultContainerDirectory, fileManager: fileManager)
    }

    public init(containerDirectory: URL, fileManager: FileManager = .default) {
        self.containerDirectory = containerDirectory
        self.fileManager = fileManager
    }

    public func write(_ request: FinderActionRequest) throws {
        try fileManager.createDirectory(at: containerDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder.rightClick.encode(request)
        try data.write(to: requestURL, options: .atomic)
    }

    public func readLatest() throws -> FinderActionRequest {
        guard fileManager.fileExists(atPath: requestURL.path) else {
            throw ActionError.malformedRequest
        }

        do {
            let data = try Data(contentsOf: requestURL)
            return try JSONDecoder.rightClick.decode(FinderActionRequest.self, from: data)
        } catch {
            throw ActionError.malformedRequest
        }
    }

    private var requestURL: URL {
        containerDirectory.appendingPathComponent(Self.defaultFileName)
    }
}

public enum ActionRequestPayloadCodec {
    public static func encode(_ request: FinderActionRequest) throws -> String {
        let data = try JSONEncoder.rightClick.encode(request)
        return data.rightClickBase64URLEncodedString()
    }

    public static func decode(_ value: String) throws -> FinderActionRequest {
        guard let data = Data(rightClickBase64URLEncoded: value) else {
            throw ActionError.malformedRequest
        }
        do {
            return try JSONDecoder.rightClick.decode(FinderActionRequest.self, from: data)
        } catch {
            throw ActionError.malformedRequest
        }
    }
}

private extension JSONEncoder {
    static var rightClick: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601DateFormatter.rightClick.string(from: date))
        }
        return encoder
    }
}

private extension JSONDecoder {
    static var rightClick: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = ISO8601DateFormatter.rightClick.date(from: value)
                ?? ISO8601DateFormatter.rightClickWithoutFractionalSeconds.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(value)")
            }
            return date
        }
        return decoder
    }
}

private extension ISO8601DateFormatter {
    static let rightClick: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let rightClickWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private extension Data {
    init?(rightClickBase64URLEncoded value: String) {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        self.init(base64Encoded: base64)
    }

    func rightClickBase64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
