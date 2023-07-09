import Foundation

public struct Auth: Sendable {
  public typealias IsSignedIn = @Sendable () async -> Bool
  public typealias IsSignedInStream = @Sendable () -> AsyncStream<Bool>
  public typealias SignIn = @Sendable () async -> Void
  public typealias HandleRedirect = @Sendable (URL) async throws -> Bool
  public typealias RefreshToken = @Sendable () async throws -> Void
  public typealias SignOut = @Sendable () async -> Void

  public enum Error: Swift.Error, Sendable, Equatable {
    case codeError(String)
    case codeNotFoundInRedirectURL
    case response(statusCode: Int?, data: Data)
  }

  public init(
    isSignedIn: @escaping IsSignedIn,
    isSignedInStream: @escaping IsSignedInStream,
    signIn: @escaping SignIn,
    handleRedirect: @escaping HandleRedirect,
    refreshToken: @escaping RefreshToken,
    signOut: @escaping SignOut
  ) {
    self.isSignedIn = isSignedIn
    self.isSignedInStream = isSignedInStream
    self.signIn = signIn
    self.handleRedirect = handleRedirect
    self.refreshToken = refreshToken
    self.signOut = signOut
  }

  public var isSignedIn: IsSignedIn
  public var isSignedInStream: IsSignedInStream
  public var signIn: SignIn
  public var handleRedirect: HandleRedirect
  public var refreshToken: RefreshToken
  public var signOut: SignOut
}

extension Auth {
  public static func live(
    config: Config,
    keychain: Keychain,
    httpClient: HTTPClient,
    openURL: OpenURL,
    dateGenerator now: DateGenerator,
    pkceUtils pkce: PKCEUtils
  ) -> Auth {
    let isSignedIn = CurrentValueAsyncSequence(false)
    let codeVerifier = ActorIsolated<String?>(nil)

    @Sendable
    func checkSignedIn() async {
      let value = await keychain.loadCredentials() != nil
      if await isSignedIn.value != value {
        await isSignedIn.setValue(value)
      }
    }

    @Sendable
    func saveCredentials(_ credentials: Credentials?) async {
      if let credentials {
        await keychain.saveCredentials(credentials)
      } else {
        await keychain.deleteCredentials()
      }
      await checkSignedIn()
    }

    return Auth(
      isSignedIn: {
        await checkSignedIn()
        return await isSignedIn.value
      },
      isSignedInStream: {
        Task { await checkSignedIn() }
        return {
          var iterator: AsyncStream<Bool>.Iterator?
          return AsyncStream {
            if iterator == nil {
              iterator = isSignedIn.makeAsyncIterator()
            }
            return await iterator?.next()
          }
        }()
      },
      signIn: {
        let _codeVerifier = pkce.codeVerifier()
        await codeVerifier.setValue(_codeVerifier)
        let codeChallenge = pkce.codeChallenge(from: _codeVerifier)

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.dropbox.com"
        components.path = "/oauth2/authorize"
        components.queryItems = [
          URLQueryItem(name: "client_id", value: config.appKey),
          URLQueryItem(name: "code_challenge", value: codeChallenge),
          URLQueryItem(name: "code_challenge_method", value: "S256"),
          URLQueryItem(name: "disable_signup", value: "true"),
          URLQueryItem(name: "redirect_uri", value: config.redirectURI),
          URLQueryItem(name: "response_type", value: "code"),
          URLQueryItem(name: "token_access_type", value: "offline"),
        ]
        if let scope = config.authScope {
          components.queryItems?.append(
            URLQueryItem(name: "scope", value: scope)
          )
        }

        let url = components.url!
        await openURL(url)
      },
      handleRedirect: { url in
        guard let codeVerifier = await codeVerifier.value else { return false }
        guard url.absoluteString.starts(with: config.redirectURI) else { return false }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let code = components?.queryItems?.first(where: { $0.name == "code" })?.value
        let error = components?.queryItems?.first(where: { $0.name == "error" })?.value

        if let error { throw Error.codeError(error) }
        guard let code else { throw Error.codeNotFoundInRedirectURL }

        let request: URLRequest = {
          var components = URLComponents()
          components.scheme = "https"
          components.host = "api.dropboxapi.com"
          components.path = "/oauth2/token"

          var request = URLRequest(url: components.url!)
          request.httpMethod = "POST"
          request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
          )
          request.httpBody = [
            "code=\(code)",
            "grant_type=authorization_code",
            "redirect_uri=\(config.redirectURI)",
            "code_verifier=\(codeVerifier)",
            "client_id=\(config.appKey)",
          ].joined(separator: "&").data(using: .utf8)

          return request
        }()

        let (responseData, response) = try await httpClient.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode

        guard let statusCode, (200..<300).contains(statusCode) else {
          throw Error.response(statusCode: statusCode, data: responseData)
        }

        struct ResponseBody: Decodable {
          var accessToken: String
          var tokenType: String
          var expiresIn: Int
          var refreshToken: String
          var scope: String
          var uid: String
          var accountId: String
        }

        let responseBody = try JSONDecoder.api.decode(
          ResponseBody.self,
          from: responseData
        )
        let credentials = Credentials(
          accessToken: responseBody.accessToken,
          tokenType: responseBody.tokenType,
          expiresAt: Date(
            timeInterval: TimeInterval(responseBody.expiresIn),
            since: now()
          ),
          refreshToken: responseBody.refreshToken,
          scope: responseBody.scope,
          uid: responseBody.uid,
          accountId: responseBody.accountId
        )

        await saveCredentials(credentials)

        return true
      },
      refreshToken: {
        guard let credentials = await keychain.loadCredentials() else { return }
        guard credentials.expiresAt <= now() else { return }

        let request: URLRequest = {
          var components = URLComponents()
          components.scheme = "https"
          components.host = "api.dropboxapi.com"
          components.path = "/oauth2/token"

          var request = URLRequest(url: components.url!)
          request.httpMethod = "POST"
          request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
          )
          request.httpBody = [
            "grant_type=refresh_token",
            "refresh_token=\(credentials.refreshToken)",
            "client_id=\(config.appKey)",
          ].joined(separator: "&").data(using: .utf8)

          return request
        }()

        let (responseData, response) = try await httpClient.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode

        guard let statusCode, (200..<300).contains(statusCode) else {
          await saveCredentials(nil)
          throw Error.response(statusCode: statusCode, data: responseData)
        }

        struct ResponseBody: Decodable {
          var accessToken: String
          var tokenType: String
          var expiresIn: Int
        }

        let responseBody = try JSONDecoder.api.decode(
          ResponseBody.self,
          from: responseData
        )

        var newCredentials = credentials
        newCredentials.accessToken = responseBody.accessToken
        newCredentials.tokenType = responseBody.tokenType
        newCredentials.expiresAt = Date(
          timeInterval: TimeInterval(responseBody.expiresIn),
          since: now()
        )

        await saveCredentials(newCredentials)
      },
      signOut: {
        await saveCredentials(nil)
      }
    )
  }
}
