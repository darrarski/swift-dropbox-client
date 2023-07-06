import Dependencies
import DropboxClient
import Logging
import SwiftUI

struct ExampleView: View {
  @Dependency(\.dropboxClient) var client
  let log = Logger(label: Bundle.main.bundleIdentifier!)

  var body: some View {
    Button {
      log.error("Not implemented")
    } label: {
      Text(String(describing: client))
    }
  }
}

#if DEBUG
struct ExampleView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      ExampleView()
    }
  }
}
#endif
