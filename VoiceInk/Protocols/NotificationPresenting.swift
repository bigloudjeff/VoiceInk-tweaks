import SwiftUI

@MainActor
protocol NotificationPresenting {
 func showNotification(
  title: String,
  type: AppNotificationView.NotificationType,
  duration: TimeInterval,
  onTap: (() -> Void)?
 )
}

extension NotificationPresenting {
 func showNotification(
  title: String,
  type: AppNotificationView.NotificationType,
  duration: TimeInterval = 3.0,
  onTap: (() -> Void)? = nil
 ) {
  showNotification(title: title, type: type, duration: duration, onTap: onTap)
 }
}
