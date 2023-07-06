import Dependencies
import DropboxClient

extension DropboxClient.Client: DependencyKey {
  public static let liveValue = Client.live(
    config: Config(
      appKey: "3wmt82ponra7r9v",
      redirectURI: "db-3wmt82ponra7r9v://swift-dropbox-example"
    )
  )

  public static let previewValue: Client = {
    let isSignedIn = CurrentValueAsyncSequence(false)
    return Client(
      auth: .init(
        isSignedIn: { await isSignedIn.value },
        isSignedInStream: { isSignedIn.eraseToStream() },
        signIn: { await isSignedIn.setValue(true) },
        handleRedirect: { _ in },
        signOut: { await isSignedIn.setValue(false) }
      )
    )
  }()
}

extension DependencyValues {
  var dropboxClient: DropboxClient.Client {
    get { self[DropboxClient.Client.self] }
    set { self[DropboxClient.Client.self] = newValue }
  }
}
