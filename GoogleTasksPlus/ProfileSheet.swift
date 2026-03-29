import SwiftUI

struct ProfileSheet: View {
    @EnvironmentObject var authService: GoogleAuthService
    @Binding var showingProfile: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(DB.navBackground)

            if let email = authService.userEmail {
                Text(email)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DB.textPrimary)
            }

            Text("Using gcloud application credentials")
                .font(.system(size: 12))
                .foregroundColor(DB.textSecondary)

            Spacer()

            HStack(spacing: 12) {
                Button("Close") {
                    showingProfile = false
                }
                .keyboardShortcut(.cancelAction)

                Button(action: {
                    authService.signOut()
                    showingProfile = false
                }) {
                    Text("Sign Out")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(DB.red)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
        }
        .padding()
    }
}
