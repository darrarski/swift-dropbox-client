import Dependencies
import DropboxClient

extension DropboxClient.Client: DependencyKey {
  public static let liveValue = Client.live()
  public static let previewValue = Client()
}

extension DependencyValues {
  var dropboxClient: DropboxClient.Client {
    get { self[DropboxClient.Client.self] }
    set { self[DropboxClient.Client.self] = newValue }
  }
}
