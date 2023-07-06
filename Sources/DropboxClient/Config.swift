public struct Config: Equatable, Sendable {
  public init(
    appKey: String,
    authScope: String? = nil,
    redirectURI: String
  ) {
    self.appKey = appKey
    self.authScope = authScope
    self.redirectURI = redirectURI
  }

  public var appKey: String
  public var authScope: String?
  public var redirectURI: String
}
