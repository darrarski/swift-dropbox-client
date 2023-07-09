import Foundation

public struct UploadFile: Sendable {
  public struct Params: Sendable, Equatable, Encodable {
    public enum Mode: String, Sendable, Equatable, Encodable {
      case add, overwrite
    }

    public init(
      path: String,
      data: Data,
      mode: Mode? = nil,
      autorename: Bool? = nil
    ) {
      self.path = path
      self.data = data
      self.mode = mode
      self.autorename = autorename
    }

    public var path: String
    public var data: Data
    public var mode: Mode?
    public var autorename: Bool?
  }

  public enum Error: Swift.Error, Sendable, Equatable {
    case notAuthorized
    case response(statusCode: Int?, data: Data)
  }

  public typealias Run = @Sendable (Params) async throws -> FileMetadata

  public init(run: @escaping Run) {
    self.run = run
  }

  public var run: Run

  public func callAsFunction(_ params: Params) async throws -> FileMetadata {
    try await run(params)
  }

  public func callAsFunction(
    path: String,
    data: Data,
    mode: Params.Mode? = nil,
    autorename: Bool? = nil
  ) async throws -> FileMetadata {
    try await run(.init(
      path: path,
      data: data,
      mode: mode,
      autorename: autorename
    ))
  }
}

extension UploadFile {
  public static func live(
    keychain: Keychain,
    httpClient: HTTPClient
  ) -> UploadFile {
    UploadFile { params in
      guard let credentials = await keychain.loadCredentials() else {
        throw Error.notAuthorized
      }

      let request: URLRequest = try {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "content.dropboxapi.com"
        components.path = "/2/files/upload"

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(
          "\(credentials.tokenType) \(credentials.accessToken)",
          forHTTPHeaderField: "Authorization"
        )

        struct Args: Encodable {
          var path: String
          var mode: String?
          var autorename: Bool?
        }
        let args = Args(
          path: params.path,
          mode: params.mode?.rawValue,
          autorename: params.autorename
        )
        let argsData = try JSONEncoder.api.encode(args)
        let argsString = String(data: argsData, encoding: .utf8)

        request.setValue(
          argsString,
          forHTTPHeaderField: "Dropbox-API-Arg"
        )
        request.setValue(
          "application/octet-stream",
          forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = params.data

        return request
      }()

      let (responseData, response) = try await httpClient.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      guard let statusCode, (200..<300).contains(statusCode) else {
        throw Error.response(statusCode: statusCode, data: responseData)
      }

      let metadata = try JSONDecoder.api.decode(FileMetadata.self, from: responseData)
      return metadata
    }
  }
}
