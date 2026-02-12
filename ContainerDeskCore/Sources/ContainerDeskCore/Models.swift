import Foundation

public enum ContainerState: String, Sendable, Hashable {
    case running
    case stopped
    case unknown
}

public struct ContainerSummary: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let image: String
    public let status: String
    public let state: ContainerState
    public let createdAt: String?
    public let ports: String?
    public let ipAddress: String?
    public let raw: [String: JSONValue]

    public init(
        id: String,
        name: String,
        image: String,
        status: String,
        state: ContainerState,
        createdAt: String?,
        ports: String?,
        ipAddress: String?,
        raw: [String: JSONValue]
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.status = status
        self.state = state
        self.createdAt = createdAt
        self.ports = ports
        self.ipAddress = ipAddress
        self.raw = raw
    }

    public init(raw: [String: JSONValue]) {
        // Try common key variants (case-insensitive).
        let id = raw.firstString(forKeys: ["id", "containerid", "container_id", "uuid"]) ?? UUID().uuidString
        let name = raw.firstString(forKeys: ["name", "names", "container", "containername"]) ?? id.prefix(12).description
        let image = raw.firstString(forKeys: ["image", "image_ref", "imageref", "imageid"]) ?? "(unknown)"
        let status = raw.firstString(forKeys: ["status", "state", "runningstate", "health"]) ?? ""
        let createdAt = raw.firstString(forKeys: ["createdat", "created_at", "created", "age", "createdsince", "runningfor"])
        let ports = raw.firstString(forKeys: ["ports", "publishedports", "publish", "published"])
        let ip = raw.firstString(forKeys: ["ip", "ipaddress", "ip_address", "address"])

        let lowered = (status.isEmpty ? (raw.firstString(forKeys: ["state"]) ?? "") : status).lowercased()
        let state: ContainerState
        if lowered.contains("running") || lowered == "run" || lowered == "up" {
            state = .running
        } else if lowered.contains("stopped") || lowered.contains("exited") || lowered == "stop" || lowered == "down" {
            state = .stopped
        } else {
            state = .unknown
        }

        self.init(
            id: id,
            name: name,
            image: image,
            status: status.isEmpty ? lowered : status,
            state: state,
            createdAt: createdAt,
            ports: ports,
            ipAddress: ip,
            raw: raw
        )
    }
}

public struct ImageSummary: Identifiable, Sendable, Hashable {
    public let id: String
    public let repository: String
    public let tag: String
    public let size: String?
    public let createdAt: String?
    public let raw: [String: JSONValue]

    public var reference: String {
        if repository.isEmpty { return id }
        if tag.isEmpty { return repository }
        return "\(repository):\(tag)"
    }

    public init(id: String, repository: String, tag: String, size: String?, createdAt: String?, raw: [String: JSONValue]) {
        self.id = id
        self.repository = repository
        self.tag = tag
        self.size = size
        self.createdAt = createdAt
        self.raw = raw
    }

    public init(raw: [String: JSONValue]) {
        let id = raw.firstString(forKeys: ["id", "imageid", "digest", "sha", "hash"]) ?? UUID().uuidString
        let repo = raw.firstString(forKeys: ["repository", "repo", "name", "image", "reference"]) ?? ""
        let tag = raw.firstString(forKeys: ["tag", "tags"]) ?? ""
        let size = raw.firstString(forKeys: ["size", "virtualsize", "disk"])
        let createdAt = raw.firstString(forKeys: ["createdat", "created_at", "created", "age", "createdsince"])

        self.init(id: id, repository: repo, tag: tag, size: size, createdAt: createdAt, raw: raw)
    }
}

public struct BuilderStatus: Sendable, Hashable {
    public let isRunning: Bool
    public let message: String
    public let raw: JSONValue?

    public init(isRunning: Bool, message: String, raw: JSONValue? = nil) {
        self.isRunning = isRunning
        self.message = message
        self.raw = raw
    }
}

public struct SystemStatus: Sendable, Hashable {
    public let isRunning: Bool
    public let message: String

    public init(isRunning: Bool, message: String) {
        self.isRunning = isRunning
        self.message = message
    }

    public static let unknown = SystemStatus(isRunning: false, message: "Unknown")
}
