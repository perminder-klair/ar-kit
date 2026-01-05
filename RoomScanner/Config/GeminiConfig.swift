import Foundation

/// Configuration manager for Gemini API
final class GeminiConfig {

    static let shared = GeminiConfig()

    private init() {}

    /// Attempts to load API key from multiple sources (priority order):
    /// 1. Environment variable GEMINI_API_KEY
    /// 2. GeminiAPIKey.plist in bundle
    /// 3. UserDefaults (for runtime configuration)
    var apiKey: String? {
        // 1. Environment variable (for CI/CD or testing)
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
           !envKey.isEmpty {
            return envKey
        }

        // 2. Plist file (for local development)
        if let plistPath = Bundle.main.path(forResource: "GeminiAPIKey", ofType: "plist"),
           let plistData = FileManager.default.contents(atPath: plistPath),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
           let key = plist["API_KEY"] as? String,
           !key.isEmpty,
           key != "YOUR_GEMINI_API_KEY_HERE" {
            return key
        }

        // 3. UserDefaults (for runtime configuration)
        if let key = UserDefaults.standard.string(forKey: "GeminiAPIKey"),
           !key.isEmpty {
            return key
        }

        return nil
    }

    /// Check if API is configured
    var isConfigured: Bool {
        apiKey != nil
    }

    /// Set API key at runtime (persists to UserDefaults)
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "GeminiAPIKey")
    }

    /// Clear stored API key
    func clearAPIKey() {
        UserDefaults.standard.removeObject(forKey: "GeminiAPIKey")
    }
}
