import Foundation

public struct DeleteFile: Sendable {
  public struct Params: Sendable, Equatable, Encodable {
    public init(path: String) {
      self.path = path
    }

    public var path: String
  }

  public struct Result: Sendable, Equatable, Decodable {
    public init(metadata: Metadata) {
      self.metadata = metadata
    }

    public var metadata: Metadata
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

  public func callAsFunction(path: String) async throws -> Result {
    try await run(.init(path: path))
  }
}

extension DeleteFile {
  public static func live(
    auth: Auth,
    keychain: Keychain,
    httpClient: HTTPClient
  ) -> DeleteFile {
    DeleteFile { params in
      try await auth.refreshToken()

      guard let credentials = await keychain.loadCredentials() else {
        throw Error.notAuthorized
      }

      let request: URLRequest = try {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.dropboxapi.com"
        components.path = "/2/files/delete_v2"

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

      let result = try JSONDecoder.api.decode(Result.self, from: responseData)
      return result
    }
  }
}
