import XCTest
@testable import DropboxClient

final class UploadFileTests: XCTestCase {
  func testUploadFile() async throws {
    let params = UploadFile.Params(
      path: "/Prime_Numbers.txt",
      data: "2,3,5,7...".data(using: .utf8)!,
      mode: .add,
      autorename: true
    )
    let credentials = Credentials.test
    let didRefreshToken = ActorIsolated(0)
    let httpRequests = ActorIsolated<[URLRequest]>([])
    let uploadFile = UploadFile.live(
      auth: {
        var auth = Auth.unimplemented()
        auth.refreshToken = {
          await didRefreshToken.withValue { $0 += 1 }
        }
        return auth
      }(),
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { credentials }
        return keychain
      }(),
      httpClient: .init { request in
        await httpRequests.withValue { $0.append(request) }
        return (
          """
          {
            "id": "id:a4ayc_80_OEAAAAAAAAAXw",
            "name": "Prime_Numbers.txt",
            "path_display": "/Homework/math/Prime_Numbers.txt",
            "path_lower": "/homework/math/prime_numbers.txt",
            "client_modified": "2023-07-06T15:50:38Z",
            "server_modified": "2023-07-06T22:10:00Z",
            "is_downloadable": true
          }
          """.data(using: .utf8)!,
          HTTPURLResponse(
            url: URL(filePath: "/"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
          )!
        )
      }
    )

    let result = try await uploadFile(params)

    await didRefreshToken.withValue {
      XCTAssertEqual($0, 1)
    }
    try await httpRequests.withValue {
      let url = URL(string: "https://content.dropboxapi.com/2/files/upload")!
      var expectedRequest = URLRequest(url: url)
      expectedRequest.httpMethod = "POST"
      struct Args: Encodable {
        var path: String
        var mode: String?
        var autorename: Bool?
      }
      expectedRequest.allHTTPHeaderFields = [
        "Authorization": "\(credentials.tokenType) \(credentials.accessToken)",
        "Dropbox-API-Arg": String(
          data: try JSONEncoder.api.encode(Args(
            path: params.path,
            mode: params.mode!.rawValue,
            autorename: params.autorename!
          )),
          encoding: .utf8
        )!,
        "Content-Type": "application/octet-stream"
      ]
      expectedRequest.httpBody = params.data

      XCTAssertEqual($0, [expectedRequest])
      XCTAssertEqual($0.first?.httpBody, expectedRequest.httpBody!)
    }
    XCTAssertEqual(result, FileMetadata(
      id: "id:a4ayc_80_OEAAAAAAAAAXw",
      name: "Prime_Numbers.txt",
      pathDisplay: "/Homework/math/Prime_Numbers.txt",
      pathLower: "/homework/math/prime_numbers.txt",
      clientModified: Calendar(identifier: .gregorian)
        .date(from: DateComponents(
          timeZone: TimeZone(secondsFromGMT: 0),
          year: 2023, month: 7, day: 6,
          hour: 15, minute: 50, second: 38
        ))!,
      serverModified: Calendar(identifier: .gregorian)
        .date(from: DateComponents(
          timeZone: TimeZone(secondsFromGMT: 0),
          year: 2023, month: 7, day: 6,
          hour: 22, minute: 10
        ))!,
      isDownloadable: true
    ))
  }

  func testUploadFileErrorResponse() async {
    let uploadFile = UploadFile.live(
      auth: {
        var auth = Auth.unimplemented()
        auth.refreshToken = {}
        return auth
      }(),
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { .test }
        return keychain
      }(),
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
      }
    )

    do {
      _ = try await uploadFile(path: "/test.txt", data: Data())
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? UploadFile.Error,
        .response(
          statusCode: 500,
          data: "Error!!!".data(using: .utf8)!
        ),
        "Expected to throw response error, got \(error)"
      )
    }
  }

  func testUploadFileWhenNotAuthorized() async {
    let uploadFile = UploadFile.live(
      auth: {
        var auth = Auth.unimplemented()
        auth.refreshToken = {}
        return auth
      }(),
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { nil }
        return keychain
      }(),
      httpClient: .unimplemented()
    )

    do {
      _ = try await uploadFile(path: "/test.txt", data: Data())
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? UploadFile.Error, .notAuthorized,
        "Expected to throw .notAuthorized, got \(error)"
      )
    }
  }
}
