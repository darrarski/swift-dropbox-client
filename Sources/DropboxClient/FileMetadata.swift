import Foundation

public struct FileMetadata: Sendable, Equatable, Identifiable, Decodable {
  public init(
    id: String,
    name: String,
    pathDisplay: String,
    pathLower: String,
    clientModified: Date,
    serverModified: Date,
    isDownloadable: Bool
  ) {
    self.id = id
    self.name = name
    self.pathDisplay = pathDisplay
    self.pathLower = pathLower
    self.clientModified = clientModified
    self.serverModified = serverModified
    self.isDownloadable = isDownloadable
  }

  public var id: String
  public var name: String
  public var pathDisplay: String
  public var pathLower: String
  public var clientModified: Date
  public var serverModified: Date
  public var isDownloadable: Bool
}
