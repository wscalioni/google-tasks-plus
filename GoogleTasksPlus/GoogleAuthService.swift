import Foundation
import SwiftUI

@MainActor
class GoogleAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userEmail: String?

    private var cachedToken: String?
    private var tokenExpiry: Date?

    init() {
        Task { await checkAuth() }
    }

    // MARK: - Get token via gcloud ADC

    func getValidToken() async -> String? {
        // Return cached token if still valid (tokens last ~60 min, refresh at 50 min)
        if let token = cachedToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }

        do {
            let token = try await fetchTokenFromGcloud()
            cachedToken = token
            tokenExpiry = Date().addingTimeInterval(50 * 60) // cache for 50 minutes
            isAuthenticated = true
            return token
        } catch {
            errorMessage = "Failed to get access token: \(error.localizedDescription)"
            isAuthenticated = false
            return nil
        }
    }

    // MARK: - Check if authenticated

    func checkAuth() async {
        isLoading = true
        errorMessage = nil

        if let token = await getValidToken() {
            // Verify token works by calling tokeninfo
            var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=\(token)")!)
            if let (data, _) = try? await URLSession.shared.data(for: request) {
                if let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    userEmail = info["email"] as? String
                }
            }
            isAuthenticated = true
        }

        isLoading = false
    }

    // MARK: - Sign in (re-auth via gcloud)

    func signIn() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                process.arguments = [Config.googleAuthScript, "login"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    cachedToken = nil
                    tokenExpiry = nil
                    await checkAuth()
                } else {
                    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    errorMessage = "Authentication failed. Please run:\npython3 \(Config.googleAuthScript) login\nin your terminal."
                }
            } catch {
                errorMessage = "Could not launch auth: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    // MARK: - Sign out

    func signOut() {
        cachedToken = nil
        tokenExpiry = nil
        isAuthenticated = false
        userEmail = nil
    }

    // MARK: - Private

    private func fetchTokenFromGcloud() async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [Config.googleAuthScript, "token"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "GoogleAuth", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "gcloud token fetch failed. Run: python3 \(Config.googleAuthScript) login"])
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !token.isEmpty else {
            throw NSError(domain: "GoogleAuth", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Empty token returned"])
        }

        return token
    }
}
