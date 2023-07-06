import Foundation
import CommonCrypto

public struct PKCEUtils: Sendable {
  public typealias GenerateCodeVerifier = @Sendable () -> String
  public typealias GenerateCodeChallenge = @Sendable (String) -> String

  public init(
    generateCodeVerifier: @escaping GenerateCodeVerifier,
    generateCodeChallenge: @escaping GenerateCodeChallenge
  ) {
    self.generateCodeVerifier = generateCodeVerifier
    self.generateCodeChallenge = generateCodeChallenge
  }

  public var generateCodeVerifier: GenerateCodeVerifier
  public var generateCodeChallenge: GenerateCodeChallenge

  public func codeVerifier() -> String {
    generateCodeVerifier()
  }

  public func codeChallenge(from codeVerifier: String) -> String {
    generateCodeChallenge(codeVerifier)
  }
}

extension PKCEUtils {
  public static let live = PKCEUtils(
    generateCodeVerifier: {
      let alphanumerics = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      let length = 128
      return String((0..<length).map { _ in alphanumerics.randomElement()! })
    },
    generateCodeChallenge: { codeVerifier in
      let data = codeVerifier.data(using: .ascii)!
      var digest = [UInt8](repeating: 0, count:Int(CC_SHA256_DIGEST_LENGTH))
      _ = data.withUnsafeBytes {
        CC_SHA256($0.baseAddress, UInt32(data.count), &digest)
      }
      return Data(digest).base64EncodedString()
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "=", with: "")
    }
  )
}
