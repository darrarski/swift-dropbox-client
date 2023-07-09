import XCTest
@testable import DropboxClient

final class DeleteFileTests: XCTestCase {
  func testDeleteFile() async throws {
    let params = DeleteFile.Params(path: "/Prime_Numbers.txt")
    let credentials = Credentials.test
    let httpRequests = ActorIsolated<[URLRequest]>([])
    let deleteFile = DeleteFile.live(
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
            "metadata": {
              ".tag": "file",
              "id": "id:a4ayc_80_OEAAAAAAAAAXw",
              "name": "Prime_Numbers.txt",
              "path_display": "/Homework/math/Prime_Numbers.txt",
              "path_lower": "/homework/math/prime_numbers.txt",
              "client_modified": "2023-07-06T15:50:38Z",
              "server_modified": "2023-07-06T22:10:00Z",
              "is_downloadable": true
            }
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

    let result = try await deleteFile(params)

    try await httpRequests.withValue {
      let url = URL(string: "https://api.dropboxapi.com/2/files/delete_v2")!
      var expectedRequest = URLRequest(url: url)
      expectedRequest.httpMethod = "POST"
      expectedRequest.allHTTPHeaderFields = [
        "Authorization": "\(credentials.tokenType) \(credentials.accessToken)",
        "Content-Type": "application/json"
      ]
      expectedRequest.httpBody = try JSONEncoder.api.encode(params)

      XCTAssertEqual($0, [expectedRequest])
      XCTAssertEqual($0.first?.httpBody, expectedRequest.httpBody!)
    }
    XCTAssertEqual(result, DeleteFile.Result(
      metadata: Metadata(
        tag: .file,
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
      )
    ))
  }

  func testDeleteFileErrorResponse() async {
    let deleteFile = DeleteFile.live(
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
      _ = try await deleteFile(path: "/test.txt")
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? DeleteFile.Error,
        .response(
          statusCode: 500,
          data: "Error!!!".data(using: .utf8)!
        ),
        "Expected to throw response error, got \(error)"
      )
    }
  }

  func testDeleteFileWhenNotAuthorized() async {
    let deleteFile = DeleteFile.live(
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { nil }
        return keychain
      }(),
      httpClient: .unimplemented()
    )

    do {
      _ = try await deleteFile(path: "/test.txt")
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? DeleteFile.Error, .notAuthorized,
        "Expected to throw .notAuthorized, got \(error)"
      )
    }
  }
}
