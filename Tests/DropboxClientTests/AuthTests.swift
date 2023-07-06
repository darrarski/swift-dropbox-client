import XCTest
@testable import DropboxClient

final class AuthTests: XCTestCase {
  func testSignIn() async {
    let didOpenURL = ActorIsolated<[URL]>([])
    let auth = Auth.live(
      config: .test,
      keychain: .unimplemented(),
      httpClient: .unimplemented(),
      openURL: .init { url in
        await didOpenURL.withValue {
          $0.append(url)
          return true
        }
      },
      dateGenerator: .unimplemented(),
      pkceUtils: .init(
        generateCodeVerifier: { "test-code-verifier" },
        generateCodeChallenge: { "test-code-challenge-for-\($0)" }
      )
    )

    await auth.signIn()

    let expectedURL: URL = {
      var components = URLComponents()
      components.scheme = "https"
      components.host = "www.dropbox.com"
      components.path = "/oauth2/authorize"
      components.queryItems = [
        URLQueryItem(name: "client_id", value: Config.test.appKey),
        URLQueryItem(name: "code_challenge", value: "test-code-challenge-for-test-code-verifier"),
        URLQueryItem(name: "code_challenge_method", value: "S256"),
        URLQueryItem(name: "disable_signup", value: "true"),
        URLQueryItem(name: "redirect_uri", value: Config.test.redirectURI),
        URLQueryItem(name: "response_type", value: "code"),
        URLQueryItem(name: "token_access_type", value: "offline"),
        URLQueryItem(name: "scope", value: Config.test.authScope!)
      ]
      return components.url!
    }()
    await didOpenURL.withValue {
      XCTAssertEqual($0, [expectedURL])
    }
  }

  func testDontHandleRedirectsIfSignUpNotStarted() async throws {
    let auth = Auth.live(
      config: .test,
      keychain: .unimplemented(),
      httpClient: .unimplemented(),
      openURL: .unimplemented(),
      dateGenerator: .unimplemented(),
      pkceUtils: .unimplemented()
    )

    try await auth.handleRedirect(URL(string: Config.test.redirectURI)!)
  }

  func testIgnoreUnrelatedRedirects() async throws {
    let auth = Auth.live(
      config: .test,
      keychain: .unimplemented(),
      httpClient: .unimplemented(),
      openURL: .init { _ in true },
      dateGenerator: .unimplemented(),
      pkceUtils: .init(
        generateCodeVerifier: { "test-code-verifier" },
        generateCodeChallenge: { "test-code-challenge-for-\($0)" }
      )
    )

    await auth.signIn()

    try await auth.handleRedirect(URL(string: "https://darrarski.pl")!)
  }

  func testHandleRedirectWithError() async throws {
    let url = URL(string: "\(Config.test.redirectURI)?error=Failure")!
    let auth = Auth.live(
      config: .test,
      keychain: .unimplemented(),
      httpClient: .unimplemented(),
      openURL: .init { _ in true },
      dateGenerator: .unimplemented(),
      pkceUtils: .init(
        generateCodeVerifier: { "" },
        generateCodeChallenge: { _ in "" }
      )
    )

    await auth.signIn()

    do {
      try await auth.handleRedirect(url)
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? Auth.Error, .codeError("Failure"),
        "Expected to throw .codeError, got \(error)"
      )
    }
  }

  func testHandleRedirectWithoutCode() async {
    let url = URL(string: Config.test.redirectURI)!
    let auth = Auth.live(
      config: .test,
      keychain: .unimplemented(),
      httpClient: .unimplemented(),
      openURL: .init { _ in true },
      dateGenerator: .unimplemented(),
      pkceUtils: .init(
        generateCodeVerifier: { "" },
        generateCodeChallenge: { _ in "" }
      )
    )

    await auth.signIn()

    do {
      try await auth.handleRedirect(url)
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? Auth.Error, .codeNotFoundInRedirectURL,
        "Expected to throw codeError, got \(error)"
      )
    }
  }

  func testHandleRedirect() async throws {
    let httpRequests = ActorIsolated<[URLRequest]>([])
    let credentials = ActorIsolated<Credentials?>(nil)
    let date = Date(timeIntervalSince1970: 1_000_000)
    let code = "1234"
    let url = URL(string: "\(Config.test.redirectURI)test?code=\(code)")!
    let auth = Auth.live(
      config: .test,
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { await credentials.value }
        keychain.saveCredentials = { await credentials.setValue($0) }
        return keychain
      }(),
      httpClient: .init { request in
        await httpRequests.withValue { $0.append(request) }
        return (
          """
          {
            "access_token": "access-token-1",
            "token_type": "token-type-1",
            "expiresIn": 1234,
            "refresh_token": "refresh-token-1",
            "scope": "scope-1",
            "uid": "uid-1",
            "accountId": "account-id-1"
          }
          """.data(using: .utf8)!,
          HTTPURLResponse(
            url: URL(filePath: "/"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
          )!
        )
      },
      openURL: .init { _ in true},
      dateGenerator: .init { date },
      pkceUtils: .init(
        generateCodeVerifier: { "test-code-verifier" },
        generateCodeChallenge: { "test-code-challenge-for-\($0)" }
      )
    )

    await auth.signIn()
    try await auth.handleRedirect(url)

    await httpRequests.withValue {
      let url = URL(string: "https://api.dropboxapi.com/oauth2/token")!
      var expectedRequest = URLRequest(url: url)
      expectedRequest.httpMethod = "POST"
      expectedRequest.allHTTPHeaderFields = [
        "Content-Type": "application/x-www-form-urlencoded"
      ]
      expectedRequest.httpBody = [
        "code=\(code)",
        "grant_type=authorization_code",
        "redirect_uri=\(Config.test.redirectURI)",
        "code_verifier=test-code-verifier",
        "client_id=\(Config.test.appKey)",
      ].joined(separator: "&").data(using: .utf8)!

      XCTAssertEqual($0, [expectedRequest])
    }
    await credentials.withValue {
      XCTAssertEqual($0, Credentials(
        accessToken: "access-token-1",
        tokenType: "token-type-1",
        expiresAt: date.addingTimeInterval(1234),
        refreshToken: "refresh-token-1",
        scope: "scope-1",
        uid: "uid-1",
        accountId: "account-id-1"
      ))
    }
    let isSignedIn = await auth.isSignedIn()
    XCTAssertTrue(isSignedIn)
  }

  func testHandleRedirectErrorResponse() async {
    let date = Date(timeIntervalSince1970: 1_000_000)
    let url = URL(string: "\(Config.test.redirectURI)test?code=1234")!
    let auth = Auth.live(
      config: .test,
      keychain: .unimplemented(),
      httpClient: .init { request in
        (
          "Error!!!".data(using: .utf8)!,
          HTTPURLResponse(
            url: URL(filePath: "/"),
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
          )!
        )
      },
      openURL: .init { _ in true },
      dateGenerator: .init { date },
      pkceUtils: .init(
        generateCodeVerifier: { "" },
        generateCodeChallenge: { _ in "" }
      )
    )

    await auth.signIn()

    do {
      try await auth.handleRedirect(url)
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? Auth.Error,
        .response(
          statusCode: 500,
          data: "Error!!!".data(using: .utf8)!
        ),
        "Expected to throw response error, got \(error)"
      )
    }
  }

  func testSignOut() async {
    let credentials = ActorIsolated<Credentials?>(Credentials(
      accessToken: "",
      tokenType: "",
      expiresAt: Date(),
      refreshToken: "",
      scope: "",
      uid: "",
      accountId: ""
    ))
    let auth = Auth.live(
      config: .test,
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { await credentials.value }
        keychain.deleteCredentials = { await credentials.setValue(nil) }
        return keychain
      }(),
      httpClient: .unimplemented(),
      openURL: .unimplemented(),
      dateGenerator: .unimplemented(),
      pkceUtils: .unimplemented()
    )

    await auth.signOut()

    await credentials.withValue { XCTAssertNil($0) }
    let isSignedIn = await auth.isSignedIn()
    XCTAssertFalse(isSignedIn)
  }
}
