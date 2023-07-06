public struct Client: Sendable {
  public init() {}
}

extension Client {
  public static func live() -> Client {
    Client()
  }
}
