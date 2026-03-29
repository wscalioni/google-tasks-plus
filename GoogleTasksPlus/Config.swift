import Foundation

enum Config {
    static let quotaProject = "gcp-sandbox-field-eng"
    static let tasksBaseURL = "https://tasks.googleapis.com/tasks/v1"

    // Path to the google-auth helper script
    static let googleAuthScript = "\(NSHomeDirectory())/.vibe/marketplace/plugins/fe-google-tools/skills/google-auth/resources/google_auth.py"
}
