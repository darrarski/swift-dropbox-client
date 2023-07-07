import XCTest
@testable import DropboxClient

final class DownloadFileTests: XCTestCase {
  func testDownloadFile() async throws {
    let credentials = Credentials.test
    let httpRequests = ActorIsolated<[URLRequest]>([])
    let downloadFile = DownloadFile.live(
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { credentials }
        return keychain
      }(),
      httpClient: .init { request in
        await httpRequests.withValue { $0.append(request) }
        return (
          "test file content".data(using: .utf8)!,
          HTTPURLResponse(
            url: URL(filePath: "/"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
          )!
        )
      }
    )
    let params = DownloadFile.Params(path: "test-path")

    let result = try await downloadFile(params)

    await httpRequests.withValue {
      let expectedRequest: URLRequest = {
        let url = URL(string: "https://content.dropboxapi.com/2/files/download")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
          "Authorization": "\(credentials.tokenType) \(credentials.accessToken)",
          "Dropbox-API-Arg": String(
            data: try! JSONEncoder.api.encode(params),
            encoding: .utf8
          )!
        ]
        return request
      }()

      XCTAssertEqual($0, [expectedRequest])
      XCTAssertNil($0.first?.httpBody)
    }
    XCTAssertEqual(result, "test file content".data(using: .utf8)!)
  }

  func testDownloadFileWhenNotAuthorized() async {
    let downloadFile = DownloadFile.live(
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { nil }
        return keychain
      }(),
      httpClient: .unimplemented()
    )

    do {
      _ = try await downloadFile(path: "")
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? DownloadFile.Error, .notAuthorized,
        "Expected to throw .notAuthorized, got \(error)"
      )
    }
  }

  func testDownloadFileErrorResponse() async {
    let downloadFile = DownloadFile.live(
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { .test }
        return keychain
      }(),
      httpClient: .init { _ in
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
      _ = try await downloadFile(path: "")
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? DownloadFile.Error,
        .response(
          statusCode: 500,
          data: "Error!!!".data(using: .utf8)!
        ),
        "Expected to throw response error, got \(error)"
      )
    }
  }
}
