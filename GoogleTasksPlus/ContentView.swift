import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: GoogleAuthService
    @EnvironmentObject var tasksService: GoogleTasksService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTasksView()
            } else if authService.isLoading {
                ZStack {
                    DB.navBackground.ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Connecting to Google Tasks...")
                            .foregroundColor(DB.textOnDarkMuted)
                    }
                }
            } else {
                SignInView()
            }
        }
    }
}

// MARK: - Sign In View

struct SignInView: View {
    @EnvironmentObject var authService: GoogleAuthService

    var body: some View {
        ZStack {
            DB.navBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(DB.red)

                    Text("Tasks+")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(DB.textOnDark)

                    Text("Google Tasks, supercharged with tags")
                        .font(.system(size: 16))
                        .foregroundColor(DB.textOnDarkMuted)
                }

                Spacer()

                VStack(spacing: 16) {
                    Text("gcloud credentials not found or expired.")
                        .font(.system(size: 13))
                        .foregroundColor(DB.textOnDarkMuted)

                    Button(action: { authService.signIn() }) {
                        HStack(spacing: 12) {
                            if authService.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 20))
                            }
                            Text("Authenticate with Google")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: 300)
                        .frame(height: 48)
                        .background(DB.red)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(authService.isLoading)

                    if let error = authService.errorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(DB.warning)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 350)
                    }
                }

                Spacer()
                    .frame(height: 60)
            }
        }
    }
}
