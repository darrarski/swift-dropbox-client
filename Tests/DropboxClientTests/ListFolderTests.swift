import XCTest
@testable import DropboxClient

final class ListFolderTests: XCTestCase {
  func testListFolder() async {
    let listFolder = ListFolder.live(
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { .test }
        return keychain
      }()
    )

    do {
      _ = try await listFolder(.init())
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? ListFolder.Error, .unimplemented,
        "Expected to throw .notAuthorized, got \(error)"
      )
    }
  }

  func testListFolderWhenNotAuthorized() async {
    let listFolder = ListFolder.live(
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { nil }
        return keychain
      }()
    )

    do {
      _ = try await listFolder(.init())
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? ListFolder.Error, .notAuthorized,
        "Expected to throw .notAuthorized, got \(error)"
      )
    }
  }
}
