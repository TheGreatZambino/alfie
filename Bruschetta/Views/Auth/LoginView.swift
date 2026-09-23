import AuthenticationServices
import SwiftUI

private let termsOfUseURL = URL(string: "https://thegreatzambino.github.io/alfie/legal/terms.html")!
private let privacyPolicyURL = URL(string: "https://thegreatzambino.github.io/alfie/legal/privacy.html")!

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text("Alfie Track")
                    .font(.largeTitle.bold())
                Text("Track your budget, nutrition, and workouts in one place.")
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
            .id(colorScheme)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            legalText
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)

            Spacer(minLength: 20)
        }
        .padding()
    }

    private var legalText: Text {
        let markdown = "By continuing, you agree to my [Terms](\(termsOfUseURL.absoluteString)) and [Privacy Policy](\(privacyPolicyURL.absoluteString))."
        return Text((try? AttributedString(markdown: markdown)) ?? AttributedString(markdown))
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
