import Dependencies
import DropboxClient
import Logging
import SwiftUI

struct ExampleView: View {
  @Dependency(\.dropboxClient) var client
  let log = Logger(label: Bundle.main.bundleIdentifier!)
  @State var isSignedIn = false
  @State var list: ListFolder.Result?
  @State var fileContentAlert: String?

  var body: some View {
    Form {
      authSection
      filesSection
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
    .alert(
      "File content",
      isPresented: Binding(
        get: { fileContentAlert != nil },
        set: { isPresented in
          if !isPresented {
            fileContentAlert = nil
          }
        }
      ),
      presenting: fileContentAlert,
      actions: { _ in Button("OK") {} },
      message: { Text($0) }
    )
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

  @ViewBuilder
  var filesSection: some View {
    Section("Files") {
      Button {
        Task<Void, Never> {
          do {
            list = try await client.listFolder(path: "")
          } catch {
            log.error("ListFolder failure", metadata: [
              "error": "\(error)",
              "localizedDescription": "\(error.localizedDescription)"
            ])
          }
        }
      } label: {
        Text("List Folder")
      }
    }

    if let list {
      if list.entries.isEmpty {
        Section {
          Text("No entries")
        }
      } else {
        ForEach(list.entries) { entry in
          listEntrySection(entry)
        }
      }
    }
  }

  func listEntrySection(_ entry: Metadata) -> some View {
    Section {
      VStack(alignment: .leading) {
        Text("Tag").font(.caption).foregroundColor(.secondary)
        Text(entry.tag.rawValue)
      }

      VStack(alignment: .leading) {
        Text("ID").font(.caption).foregroundColor(.secondary)
        Text(entry.id)
      }

      VStack(alignment: .leading) {
        Text("Name").font(.caption).foregroundColor(.secondary)
        Text(entry.name)
      }

      VStack(alignment: .leading) {
        Text("Path (display)").font(.caption).foregroundColor(.secondary)
        Text(entry.pathDisplay)
      }

      VStack(alignment: .leading) {
        Text("Path (lower)").font(.caption).foregroundColor(.secondary)
        Text(entry.pathLower)
      }

      VStack(alignment: .leading) {
        Text("Client modified").font(.caption).foregroundColor(.secondary)
        Text(entry.clientModified.formatted(date: .complete, time: .complete))
      }

      VStack(alignment: .leading) {
        Text("Server modified").font(.caption).foregroundColor(.secondary)
        Text(entry.serverModified.formatted(date: .complete, time: .complete))
      }

      Button {
        Task<Void, Never> {
          do {
            let data = try await client.downloadFile(path: entry.id)
            if let string = String(data: data, encoding: .utf8) {
              fileContentAlert = string
            } else {
              fileContentAlert = data.base64EncodedString()
            }
          } catch {
            log.error("DownloadFile failure", metadata: [
              "error": "\(error)",
              "localizedDescription": "\(error.localizedDescription)"
            ])
          }
        }
      } label: {
        Text("Download File")
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
