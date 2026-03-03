import Foundation

enum BuildInfo {
 static let buildDate = "2026-03-03 13:50:40"

 static var version: String {
  Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
 }

 static var buildNumber: String {
  Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
 }

 static var summary: String {
  "v\(version) (\(buildNumber)) - \(buildDate)"
 }
}
