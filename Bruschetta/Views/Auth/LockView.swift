import SwiftUI

struct LockView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var didFail = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundStyle(Color.money)

            Text("Alfie is Locked")
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
        .task {
            await authenticate()
        }
    }

    private func authenticate() async {
        didFail = false
        let success = await authManager.unlockWithBiometrics()
        didFail = !success
    }
}

#Preview {
    LockView()
        .environmentObject(AuthManager())
}
