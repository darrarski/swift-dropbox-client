import Foundation

public struct ListFolder: Sendable {
  public struct Params: Sendable, Equatable, Encodable {
    public init(
      path: String,
      recursive: Bool? = nil,
      includeDeleted: Bool? = nil,
      limit: Int? = nil,
      includeNonDownloadableFiles: Bool? = nil
    ) {
      self.path = path
      self.recursive = recursive
      self.includeDeleted = includeDeleted
      self.limit = limit
      self.includeNonDownloadableFiles = includeNonDownloadableFiles
    }

    public var path: String
    public var recursive: Bool?
    public var includeDeleted: Bool?
    public var limit: Int?
    public var includeNonDownloadableFiles: Bool?
  }

  public struct Result: Sendable, Equatable, Decodable {
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
    case response(statusCode: Int?, data: Data)
  }

  public typealias Run = @Sendable (Params) async throws -> Result

  public init(run: @escaping Run) {
    self.run = run
  }

  public var run: Run

  public func callAsFunction(_ params: Params) async throws -> Result {
    try await run(params)
  }

  public func callAsFunction(
    path: String,
    recursive: Bool? = nil,
    includeDeleted: Bool? = nil,
    limit: Int? = nil,
    includeNonDownloadableFiles: Bool? = nil
  ) async throws -> Result {
    try await run(.init(
      path: path,
      recursive: recursive,
      includeDeleted: includeDeleted,
      limit: limit,
      includeNonDownloadableFiles: includeNonDownloadableFiles
    ))
  }
}

extension ListFolder {
  public static func live(
    auth: Auth,
    keychain: Keychain,
    httpClient: HTTPClient
  ) -> ListFolder {
    ListFolder { params in
      try await auth.refreshToken()

      guard let credentials = await keychain.loadCredentials() else {
        throw Error.notAuthorized
      }

      let request: URLRequest = try {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.dropboxapi.com"
        components.path = "/2/files/list_folder"

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(
          "\(credentials.tokenType) \(credentials.accessToken)",
          forHTTPHeaderField: "Authorization"
        )
        request.setValue(
          "application/json",
          forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = try JSONEncoder.api.encode(params)

        return request
      }()

      let (responseData, response) = try await httpClient.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      guard let statusCode, (200..<300).contains(statusCode) else {
        throw Error.response(statusCode: statusCode, data: responseData)
      }

      return try JSONDecoder.api.decode(Result.self, from: responseData)
    }
  }
}
