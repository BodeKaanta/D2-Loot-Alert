import UserNotifications

// Adds the alert's picture on iPhone and iPad (#17).
//
// iOS can't show an image straight from a push. Instead, for every push that has
// `mutable-content` set (backend/alerts.py sets it when there's an image), iOS
// starts this small extension, separate from the app, and gives it about 30
// seconds to change the alert before showing it. We download the image the
// backend put in `fcm_options.image` (the weapon icon, or the armor piece's) and
// attach it. iOS shows an attachment as the thumbnail, and bigger when the alert
// is expanded.
//
// Plain Swift, no Firebase SDK: reading one field and downloading one file
// doesn't need it.
class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var content: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    content = request.content.mutableCopy() as? UNMutableNotificationContent

    guard let options = request.content.userInfo["fcm_options"] as? [String: Any],
          let link = options["image"] as? String,
          let url = URL(string: link)
    else {
      finish() // no picture: show the alert as it came
      return
    }

    URLSession.shared.downloadTask(with: url) { [weak self] file, response, _ in
      // The downloaded file is deleted when this closure returns, so attach it now.
      if let file, (response as? HTTPURLResponse)?.statusCode == 200,
         let attachment = Self.attachment(movingFile: file, from: url) {
        self?.content?.attachments = [attachment]
      }
      self?.finish() // with or without the picture, never drop the alert
    }.resume()
  }

  /// iOS calls this when the 30 seconds are nearly up: show the alert without the picture.
  override func serviceExtensionTimeWillExpire() {
    finish()
  }

  /// Hands the alert back to iOS. Only the first call counts, since the download
  /// and the timeout can both end up here.
  private func finish() {
    guard let contentHandler, let content else { return }
    self.contentHandler = nil
    contentHandler(content)
  }

  /// iOS decides the file type from its extension, and the download has none, so
  /// move it to a temporary file named after the URL's (".jpg", ".png").
  private static func attachment(movingFile file: URL, from url: URL) -> UNNotificationAttachment? {
    let type = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
    let target = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(type)
    do {
      try FileManager.default.moveItem(at: file, to: target)
      return try UNNotificationAttachment(identifier: "image", url: target)
    } catch {
      return nil
    }
  }
}
