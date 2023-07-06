public struct Client: Sendable {
  public init(
    auth: Auth
  ) {
    self.auth = auth
  }

  public var auth: Auth
}

extension Client {
  public static func live(
    config: Config,
    keychain: Keychain = .live(),
    httpClient: HTTPClient = .urlSession(),
    openURL: OpenURL = .live,
    dateGenerator: DateGenerator = .live,
    pkceUtils: PKCEUtils = .live
  ) -> Client {
    Client(
      auth: .live(
        config: config,
        keychain: keychain,
        httpClient: httpClient,
        openURL: openURL,
        dateGenerator: dateGenerator,
        pkceUtils: pkceUtils
      )
    )
  }
}
