import AuthenticationServices
import Combine
import LocalAuthentication
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {
    @AppStorage("isSignedIn") var isSignedIn: Bool = false
    @AppStorage("userDisplayName") var userDisplayName: String = ""
    @AppStorage("authProvider") var authProvider: String = ""
    @AppStorage("appleUserID") private var appleUserID: String = ""

    /// User-facing setting, off by default: whether the app should re-lock behind
    /// Face ID / passcode when backgrounded. Most users just want to reopen the app.
    @AppStorage("appLockEnabled") var isAppLockEnabled: Bool = false

    /// Whether the current session has passed a biometric check. Not persisted — every
    /// relaunch re-derives it, and `lock()` only flips it when `isAppLockEnabled` is on.
    @Published var isUnlocked: Bool

    init() {
        isUnlocked = !UserDefaults.standard.bool(forKey: "appLockEnabled")
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            appleUserID = credential.user
            if let fullName = credential.fullName {
                let name = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !name.isEmpty {
                    userDisplayName = name
                }
            }
            authProvider = "apple"
            isSignedIn = true
            isUnlocked = true
        case .failure(let error):
            // ASAuthorizationError.canceled fires when the user dismisses the sheet; not a real failure.
            if (error as? ASAuthorizationError)?.code != .canceled {
                print("Sign in with Apple failed: \(error.localizedDescription)")
            }
        }
    }

    func signOut() {
        isSignedIn = false
        isUnlocked = false
        userDisplayName = ""
        authProvider = ""
        appleUserID = ""
    }

    func lock() {
        guard isAppLockEnabled else { return }
        isUnlocked = false
    }

    @discardableResult
    func unlockWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics/passcode enrolled on this device or simulator; don't lock the user out.
            isUnlocked = true
            return true
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Alfie"
            )
            isUnlocked = success
            return success
        } catch {
            isUnlocked = false
            return false
        }
    }
}
