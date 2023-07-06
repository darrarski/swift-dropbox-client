// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "swift-dropbox-client",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
  ],
  products: [
    .library(name: "DropboxClient", targets: ["DropboxClient"]),
  ],
  targets: [
    .target(
      name: "DropboxClient"
    ),
    .testTarget(
      name: "DropboxClientTests",
      dependencies: [
        .target(name: "DropboxClient"),
      ]
    ),
  ]
)
