public struct Client: Sendable {
  public init(
    auth: Auth,
    listFolder: ListFolder
  ) {
    self.auth = auth
    self.listFolder = listFolder
  }

  public var auth: Auth
  public var listFolder: ListFolder
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
      ),
      listFolder: .live(
        keychain: keychain,
        httpClient: httpClient
      )
    )
  }
}
