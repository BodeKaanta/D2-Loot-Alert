import UIKit
import UserNotifications
import UserNotificationsUI

// The expanded alert on iPhone and iPad (#31): the activity's banner, like the
// expanded alert on Android (#30). iOS shows the alert's title and body under it
// as usual. The collapsed alert keeps the weapon icon from NotificationService.
//
// iOS starts this extension, separately from the app, when an alert with the
// "banner" category is expanded (long-press, or pull down on the lock screen).
// The backend sets that category only when the alert has a banner, and puts the
// banner's URL in the alert's data as "banner" (backend/alerts.py).
class NotificationViewController: UIViewController, UNNotificationContentExtension {
  private let bannerView = UIImageView()

  override func viewDidLoad() {
    super.viewDidLoad()
    bannerView.contentMode = .scaleAspectFill // fill the area, trimming the edges if needed
    bannerView.clipsToBounds = true
    // The app's card color (AppColors.card), shown while the banner downloads.
    bannerView.backgroundColor = UIColor(red: 0x15 / 255, green: 0x1A / 255, blue: 0x1F / 255, alpha: 1)
    bannerView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(bannerView)
    NSLayoutConstraint.activate([
      bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      bannerView.topAnchor.constraint(equalTo: view.topAnchor),
      bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }

  /// The banner URL being shown. iOS can call didReceive again with a newer alert
  /// while one is expanded, so an older, slower download must not overwrite it.
  private var currentLink: String?
  private var bannerHidden = false

  func didReceive(_ notification: UNNotification) {
    bannerView.image = nil // never show the previous alert's banner
    guard let link = notification.request.content.userInfo["banner"] as? String,
          let url = URL(string: link)
    else {
      currentLink = nil
      hideBanner()
      return
    }
    currentLink = link
    // 10 s instead of the default 60 s: on a bad connection, fall back to the
    // normal alert quickly rather than showing an empty box for a minute.
    let request = URLRequest(url: url, timeoutInterval: 10)
    URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
      let ok = (response as? HTTPURLResponse)?.statusCode == 200
      // Decode here, in the background. Otherwise the ~1920 px banner is decoded
      // on the main thread when it's first drawn, which stutters.
      let image = ok ? data.flatMap { UIImage(data: $0)?.preparingForDisplay() } : nil
      DispatchQueue.main.async { // views may only change on the main thread
        guard let self, self.currentLink == link else { return } // a newer alert took over
        if let image {
          self.bannerView.image = image
          self.showBanner()
        } else {
          self.hideBanner()
        }
      }
    }.resume()
  }

  /// No banner after all (missing or failed to download): shrink the custom area
  /// to nothing, leaving iOS's normal title and body.
  private func hideBanner() {
    bannerHidden = true
    preferredContentSize = CGSize(width: view.bounds.width, height: 0)
  }

  /// Undoes hideBanner() if a newer alert's banner loads after an earlier one failed.
  /// The 16:9 size matches UNNotificationExtensionInitialContentSizeRatio in Info.plist.
  private func showBanner() {
    guard bannerHidden else { return } // still at the initial 16:9 size
    bannerHidden = false
    preferredContentSize = CGSize(width: view.bounds.width, height: view.bounds.width * 9 / 16)
  }
}
