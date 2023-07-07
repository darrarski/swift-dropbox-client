import XCTest
@testable import DropboxClient

final class ListFolderTests: XCTestCase {
  func testListFolder() async throws {
    let credentials = Credentials.test
    let httpRequests = ActorIsolated<[URLRequest]>([])
    let listFolder = ListFolder.live(
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
            "cursor": "c1234",
            "entries": [
              {
                ".tag": "file",
                "id": "id:a4ayc_80_OEAAAAAAAAAXw",
                "name": "Prime_Numbers.txt",
                "path_display": "/Homework/math/Prime_Numbers.txt",
                "path_lower": "/homework/math/prime_numbers.txt",
                "client_modified": "2023-07-06T15:50:38Z",
                "server_modified": "2023-07-06T22:10:00Z",
                "is_downloadable": true
              }
            ],
            "has_more": false
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

    let result = try await listFolder(
      path: "test-path",
      recursive: true,
      includeDeleted: true,
      limit: 1234,
      includeNonDownloadableFiles: false
    )

    await httpRequests.withValue {
      let expectedRequest: URLRequest = {
        let url = URL(string: "https://api.dropboxapi.com/2/files/list_folder")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
          "Authorization": "\(credentials.tokenType) \(credentials.accessToken)",
          "Content-Type": "application/json"
        ]
        return request
      }()

      XCTAssertEqual($0, [expectedRequest])
    }
    XCTAssertEqual(result, ListFolder.Result(
      cursor: "c1234",
      entries: [
        Metadata(
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
      ],
      hasMore: false
    ))
  }

  func testListFolderWhenNotAuthorized() async {
    let listFolder = ListFolder.live(
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { nil }
        return keychain
      }(),
      httpClient: .unimplemented()
    )

    do {
      _ = try await listFolder(.init(path: ""))
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? ListFolder.Error, .notAuthorized,
        "Expected to throw .notAuthorized, got \(error)"
      )
    }
  }

  func testListFolderErrorResponse() async {
    let listFolder = ListFolder.live(
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
      _ = try await listFolder(.init(path: ""))
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? ListFolder.Error,
        .response(
          statusCode: 500,
          data: "Error!!!".data(using: .utf8)!
        ),
        "Expected to throw response error, got \(error)"
      )
    }
  }
}
