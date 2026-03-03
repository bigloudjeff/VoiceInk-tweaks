import Foundation
import SwiftUI

class EnhancementShortcutSettings: ObservableObject {
    static let shared = EnhancementShortcutSettings()

    @Published var isToggleEnhancementShortcutEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isToggleEnhancementShortcutEnabled, forKey: UserDefaults.Keys.isToggleEnhancementShortcutEnabled)
            NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
        }
    }

    private init() {
        self.isToggleEnhancementShortcutEnabled = UserDefaults.standard.bool(forKey: UserDefaults.Keys.isToggleEnhancementShortcutEnabled)
    }
}
