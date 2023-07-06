import Foundation

public struct Credentials: Sendable, Equatable, Codable {
  public init(
    accessToken: String,
    tokenType: String,
    expiresAt: Date,
    refreshToken: String,
    scope: String,
    uid: String,
    accountId: String
  ) {
    self.accessToken = accessToken
    self.tokenType = tokenType
    self.expiresAt = expiresAt
    self.refreshToken = refreshToken
    self.scope = scope
    self.uid = uid
    self.accountId = accountId
  }

  public var accessToken: String
  public var tokenType: String
  public var expiresAt: Date
  public var refreshToken: String
  public var scope: String
  public var uid: String
  public var accountId: String
}
