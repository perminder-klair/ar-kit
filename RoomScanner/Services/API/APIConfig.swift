import Foundation

/// Configuration for the Report API
enum APIConfig {
    /// Base URL for the API
    /// Change this to your Vercel deployment URL in production
    #if DEBUG
    static let baseURL = "http://localhost:3000"
    #else
    static let baseURL = "https://your-app.vercel.app"  // TODO: Update with your Vercel URL
    #endif

    /// API endpoints
    enum Endpoints {
        static let reports = "/api/reports"
    }

    /// Full URL for the reports endpoint
    static var reportsURL: URL {
        URL(string: baseURL + Endpoints.reports)!
    }
}
