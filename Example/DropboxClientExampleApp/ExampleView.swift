import Dependencies
import DropboxClient
import Logging
import SwiftUI

struct ExampleView: View {
  struct Alert: Equatable {
    var title: String
    var message: String
  }

  @Dependency(\.dropboxClient) var client
  let log = Logger(label: Bundle.main.bundleIdentifier!)
  @State var isSignedIn = false
  @State var list: ListFolder.Result?
  @State var alert: Alert?

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
          _ = try await client.auth.handleRedirect(url)
        } catch {
          log.error("Auth.HandleRedirect failure", metadata: [
            "error": "\(error)",
            "localizedDescription": "\(error.localizedDescription)"
          ])
        }
      }
    }
    .alert(
      alert?.title ?? "",
      isPresented: Binding(
        get: { alert != nil },
        set: { isPresented in
          if !isPresented {
            alert = nil
          }
        }
      ),
      presenting: alert,
      actions: { _ in Button("OK") {} },
      message: { Text($0.message) }
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

      Button {
        Task<Void, Never> {
          do {
            _ = try await client.uploadFile(
              path: "/example-upload.txt",
              data: "swift-dropbox-client example uploaded file".data(using: .utf8)!,
              mode: .add,
              autorename: true
            )
          } catch {
            log.error("UploadFile failure", metadata: [
              "error": "\(error)",
              "localizedDescription": "\(error.localizedDescription)"
            ])
          }
        }
      } label: {
        Text("Upload file")
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
      Group {
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

        if let date = entry.clientModified {
          VStack(alignment: .leading) {
            Text("Client modified").font(.caption).foregroundColor(.secondary)
            Text(date.formatted(date: .complete, time: .complete))
          }
        }

        if let date = entry.serverModified {
          VStack(alignment: .leading) {
            Text("Server modified").font(.caption).foregroundColor(.secondary)
            Text(date.formatted(date: .complete, time: .complete))
          }
        }
      }

      Group {
        Button {
          Task<Void, Never> {
            do {
              let metadata = try await client.getMetadata(path: entry.pathDisplay)
              alert = Alert(title: "Metadata", message: String(describing: metadata))
            } catch {
              log.error("GetMetadata failure", metadata: [
                "error": "\(error)",
                "localizedDescription": "\(error.localizedDescription)"
              ])
            }
          }
        } label: {
          Text("Get Metadata")
        }

        Button {
          Task<Void, Never> {
            do {
              let data = try await client.downloadFile(path: entry.id)
              alert = Alert(
                title: "Content",
                message: String(data: data, encoding: .utf8) ?? data.base64EncodedString()
              )
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

        Button {
          Task<Void, Never> {
            do {
              _ = try await client.uploadFile(
                path: entry.pathDisplay,
                data: "Uploaded with overwrite at \(Date().formatted(date: .complete, time: .complete))"
                  .data(using: .utf8)!,
                mode: .overwrite,
                autorename: false
              )
            } catch {
              log.error("UploadFile failure", metadata: [
                "error": "\(error)",
                "localizedDescription": "\(error.localizedDescription)"
              ])
            }
          }
        } label: {
          Text("Upload file (overwrite)")
        }

        Button(role: .destructive) {
          Task<Void, Never> {
            do {
              _ = try await client.deleteFile(path: entry.pathDisplay)
              if let entries = list?.entries {
                list?.entries = entries.filter { $0.pathDisplay != entry.pathDisplay }
              }
            } catch {
              log.error("DeleteFile failure", metadata: [
                "error": "\(error)",
                "localizedDescription": "\(error.localizedDescription)"
              ])
            }
          }
        } label: {
          Text("Delete File")
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
