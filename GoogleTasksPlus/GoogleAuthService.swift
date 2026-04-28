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

    private static let adcPath = "\(NSHomeDirectory())/.config/gcloud/application_default_credentials.json"

    init() {
        Task { await checkAuth() }
    }

    // MARK: - Get token via ADC refresh

    func getValidToken() async -> String? {
        if let token = cachedToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }

        do {
            let token = try await refreshAccessToken()
            cachedToken = token
            tokenExpiry = Date().addingTimeInterval(50 * 60)
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
            let request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=\(token)")!)
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
            // First try reading existing ADC credentials
            cachedToken = nil
            tokenExpiry = nil
            await checkAuth()

            if !isAuthenticated {
                errorMessage = "No valid credentials found.\nPlease run in your terminal:\ngcloud auth application-default login"
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

    // MARK: - Private: read ADC file and refresh the token

    private func refreshAccessToken() async throws -> String {
        let adcURL = URL(fileURLWithPath: Self.adcPath)

        guard FileManager.default.fileExists(atPath: Self.adcPath) else {
            throw NSError(domain: "GoogleAuth", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No ADC credentials file found at \(Self.adcPath).\nRun: gcloud auth application-default login"])
        }

        let adcData = try Data(contentsOf: adcURL)
        guard let adc = try JSONSerialization.jsonObject(with: adcData) as? [String: Any],
              let clientId = adc["client_id"] as? String,
              let clientSecret = adc["client_secret"] as? String,
              let refreshToken = adc["refresh_token"] as? String else {
            throw NSError(domain: "GoogleAuth", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid ADC credentials file format"])
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientId)&client_secret=\(clientSecret)&refresh_token=\(refreshToken)&grant_type=refresh_token"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "GoogleAuth", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Token refresh failed. Run: gcloud auth application-default login"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String, !accessToken.isEmpty else {
            throw NSError(domain: "GoogleAuth", code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Empty access token in refresh response"])
        }

        return accessToken
    }
}
