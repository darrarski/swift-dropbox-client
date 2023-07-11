public struct Client: Sendable {
  public init(
    auth: Auth,
    listFolder: ListFolder,
    downloadFile: DownloadFile,
    deleteFile: DeleteFile,
    uploadFile: UploadFile,
    getMetadata: GetMetadata
  ) {
    self.auth = auth
    self.listFolder = listFolder
    self.downloadFile = downloadFile
    self.deleteFile = deleteFile
    self.uploadFile = uploadFile
    self.getMetadata = getMetadata
  }

  public var auth: Auth
  public var listFolder: ListFolder
  public var downloadFile: DownloadFile
  public var deleteFile: DeleteFile
  public var uploadFile: UploadFile
  public var getMetadata: GetMetadata
}

extension Client {
  public static func live(
    config: Config,
    keychain: Keychain = .live(),
    httpClient: HTTPClient = .urlSession(),
    openURL: OpenURL = .live,
    dateGenerator: DateGenerator = .live,
    pkceUtils: PKCEUtils = .live
  ) -> Client {
    let auth = Auth.live(
      config: config,
      keychain: keychain,
      httpClient: httpClient,
      openURL: openURL,
      dateGenerator: dateGenerator,
      pkceUtils: pkceUtils
    )

    return Client(
      auth: auth,
      listFolder: .live(
        auth: auth,
        keychain: keychain,
        httpClient: httpClient
      ),
      downloadFile: .live(
        auth: auth,
        keychain: keychain,
        httpClient: httpClient
      ),
      deleteFile: .live(
        auth: auth,
        keychain: keychain,
        httpClient: httpClient
      ),
      uploadFile: .live(
        auth: auth,
        keychain: keychain,
        httpClient: httpClient
      ),
      getMetadata: .live(
        auth: auth,
        keychain: keychain,
        httpClient: httpClient
      )
    )
  }
}
