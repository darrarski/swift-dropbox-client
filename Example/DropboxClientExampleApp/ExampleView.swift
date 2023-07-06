import Dependencies
import DropboxClient
import Logging
import SwiftUI

struct ExampleView: View {
  @Dependency(\.dropboxClient) var client
  let log = Logger(label: Bundle.main.bundleIdentifier!)
  @State var isSignedIn = false

  var body: some View {
    Form {
      authSection
    }
    .textSelection(.enabled)
    .navigationTitle("Example")
    .task {
      for await isSignedIn in client.auth.isSignedInStream() {
        self.isSignedIn = isSignedIn
      }
    }
    .onOpenURL { url in
      Task<Void, Never> {
        do {
          try await client.auth.handleRedirect(url)
        } catch {
          log.error("Auth.HandleRedirect failure", metadata: [
            "error": "\(error)",
            "localizedDescription": "\(error.localizedDescription)"
          ])
        }
      }
    }
  }

  var authSection: some View {
    Section("Auth") {
      if !isSignedIn {
        Text("You are signed out")

        Button {
          Task {
            await client.auth.signIn()
          }
        } label: {
          Text("Sign In")
        }
      } else {
        Text("You are signed in")

        Button(role: .destructive) {
          Task {
            await client.auth.signOut()
          }
        } label: {
          Text("Sign Out")
        }
      }
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
