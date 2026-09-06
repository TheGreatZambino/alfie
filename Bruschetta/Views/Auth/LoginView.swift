import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.money)
                Text("Alfie Track")
                    .font(.largeTitle.bold())
                Text("Track your budget and workouts in one place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                authManager.handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Text("By continuing, you agree to my Terms and Privacy Policy.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)

            Spacer(minLength: 20)
        }
        .padding()
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
