import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard
    
    @Published var isDarkMode: Bool {
        didSet {
            defaults.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    private init() {
        self.isDarkMode = defaults.bool(forKey: "isDarkMode")
    }
} 