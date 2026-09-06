import SwiftUI

struct LockView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var didFail = false
    @State private var isAuthenticating = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundStyle(Color.money)

            Text("Alfie Track is Locked")
                .font(.title2.bold())

            if didFail {
                Text("Authentication failed. Try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await authenticate() }
            } label: {
                Text("Unlock")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.money)
            .padding(.horizontal, 40)
            .padding(.top, 12)

            Spacer()
            Spacer()
        }
        .padding()
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await authenticate() }
        }
    }

    private func authenticate() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        didFail = false
        let success = await authManager.unlockWithBiometrics()
        didFail = !success
    }
}

#Preview {
    LockView()
        .environmentObject(AuthManager())
}
