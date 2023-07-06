# Swift Dropbox Client

![Swift v5.8](https://img.shields.io/badge/swift-v5.8-orange.svg)
![platforms iOS, macOS](https://img.shields.io/badge/platforms-iOS,_macOS-blue.svg)

Basic Dropbox HTTP API client that does not depend on Dropbox's SDK. No external dependencies.

## 📖 Usage

Use [Swift Package Manager](https://swift.org/package-manager/) to add the `DropboxClient` library as a dependency to your project. 

*TBD*

### ▶️ Example

This repository contains an [example iOS application](Example/DropboxClientExampleApp) built with SwiftUI.

- Open `DropboxClient.xcworkspace` in Xcode.
- Example source code is contained in the `Example` Xcode project.
- Run the app using the `DropboxClientExampleApp` build scheme.
- The "Example" tab provides UI that uses `DropboxClient` library.
- The "Console" tab provides UI for browsing application logs and HTTP requests.

The example app uses [Dependencies](https://github.com/pointfreeco/swift-dependencies) to manage its own internal dependencies. For more information about the `Dependencies` library check out [official documentation](https://pointfreeco.github.io/swift-dependencies/main/documentation/dependencies).

## 🏛 Project structure

```
DropboxClient (Xcode Workspace)
 ├─ swift-dropbox-client (Swift Package)
 |   └─ DropboxClient (Library)
 └─ Example (Xcode Project)
     └─ DropboxClientExampleApp (iOS Application)
```

## 🛠 Develop

- Use Xcode (version ≥ 14.3.1).
- Clone the repository or create a fork & clone it.
- Open `DropboxClient.xcworkspace` in Xcode.
- Use the `DropboxClient` scheme for building the library and running unit tests.
- If you want to contribute, create a pull request containing your changes or bug fixes. Make sure to include tests for new/updated code.

## ☕️ Do you like the project?

<a href="https://www.buymeacoffee.com/darrarski" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="60" width="217" style="height: 60px !important;width: 217px !important;" ></a>

## 📄 License

Copyright © 2023 Dariusz Rybicki Darrarski

License: [MIT](LICENSE)
