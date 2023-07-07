import Foundation

public struct ListFolder: Sendable {
  public struct Params: Sendable, Equatable {
    public init() {}
  }

  public struct Result: Sendable, Equatable {
    public init(cursor: String, entries: [Metadata], hasMore: Bool) {
      self.cursor = cursor
      self.entries = entries
      self.hasMore = hasMore
    }

    public var cursor: String
    public var entries: [Metadata]
    public var hasMore: Bool
  }

  public enum Error: Swift.Error, Sendable, Equatable {
    case notAuthorized
    case unimplemented
  }

  public typealias Run = @Sendable (Params) async throws -> Result

  public init(run: @escaping Run) {
    self.run = run
  }

  public var run: Run

  public func callAsFunction(_ params: Params) async throws -> Result {
    try await run(params)
  }
}

extension ListFolder {
  public static func live(
    keychain: Keychain
  ) -> ListFolder {
    ListFolder { params in
      guard let _ = await keychain.loadCredentials() else {
        throw Error.notAuthorized
      }
      throw Error.unimplemented
    }
  }
}
