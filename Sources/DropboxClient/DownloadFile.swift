import Foundation

public struct DownloadFile: Sendable {
  public struct Params: Sendable, Equatable, Encodable {
    public init(path: String) {
      self.path = path
    }

    public var path: String
  }

  public enum Error: Swift.Error, Sendable, Equatable {
    case notAuthorized
    case response(statusCode: Int?, data: Data)
  }

  public typealias Run = @Sendable (Params) async throws -> Data

  public init(run: @escaping Run) {
    self.run = run
  }

  public var run: Run

  public func callAsFunction(_ params: Params) async throws -> Data {
    try await run(params)
  }

  public func callAsFunction(path: String) async throws -> Data {
    try await run(.init(path: path))
  }
}

extension DownloadFile {
  public static func live(
    keychain: Keychain,
    httpClient: HTTPClient
  ) -> DownloadFile {
    DownloadFile { params in
      guard let credentials = await keychain.loadCredentials() else {
        throw Error.notAuthorized
      }

      let request: URLRequest = try {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "content.dropboxapi.com"
        components.path = "/2/files/download"

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(
          "\(credentials.tokenType) \(credentials.accessToken)",
          forHTTPHeaderField: "Authorization"
        )
        request.setValue(
          String(data: try JSONEncoder.api.encode(params), encoding: .utf8),
          forHTTPHeaderField: "Dropbox-API-Arg"
        )

        return request
      }()

      let (responseData, response) = try await httpClient.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      guard let statusCode, (200..<300).contains(statusCode) else {
        throw Error.response(statusCode: statusCode, data: responseData)
      }

      return responseData
    }
  }
}
