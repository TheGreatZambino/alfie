import Testing
import Foundation
import AuthenticationServices
@testable import Bruschetta

/// `AuthManager` reads/writes `UserDefaults.standard` directly via `@AppStorage`, so these
/// tests run serialized and reset the keys they touch to avoid cross-test interference.
@MainActor
@Suite(.serialized)
struct AuthManagerTests {
    private static let keys = ["isSignedIn", "userDisplayName", "authProvider", "appleUserID", "appLockEnabled"]

    init() {
        Self.keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    @Test
    func startsUnlockedWhenAppLockIsDisabled() {
        UserDefaults.standard.set(false, forKey: "appLockEnabled")
        let manager = AuthManager()
        #expect(manager.isUnlocked)
    }

    @Test
    func startsLockedWhenAppLockIsEnabled() {
        UserDefaults.standard.set(true, forKey: "appLockEnabled")
        let manager = AuthManager()
        #expect(!manager.isUnlocked)
    }

    @Test
    func signOutClearsSessionState() {
        let manager = AuthManager()
        manager.isSignedIn = true
        manager.isUnlocked = true
        manager.userDisplayName = "Jane Doe"
        manager.authProvider = "apple"

        manager.signOut()

        #expect(!manager.isSignedIn)
        #expect(!manager.isUnlocked)
        #expect(manager.userDisplayName.isEmpty)
        #expect(manager.authProvider.isEmpty)
    }

    @Test
    func lockIsANoOpWhenAppLockDisabled() {
        let manager = AuthManager()
        manager.isAppLockEnabled = false
        manager.isUnlocked = true

        manager.lock()

        #expect(manager.isUnlocked)
    }

    @Test
    func lockLocksWhenAppLockEnabled() {
        let manager = AuthManager()
        manager.isAppLockEnabled = true
        manager.isUnlocked = true

        manager.lock()

        #expect(!manager.isUnlocked)
    }

    @Test
    func cancelledAppleSignInDoesNotChangeSessionState() {
        let manager = AuthManager()
        manager.isSignedIn = false
        manager.isUnlocked = false

        manager.handleAppleSignIn(.failure(ASAuthorizationError(.canceled)))

        #expect(!manager.isSignedIn)
        #expect(!manager.isUnlocked)
    }

    @Test
    func failedAppleSignInDoesNotChangeSessionState() {
        let manager = AuthManager()
        manager.isSignedIn = false
        manager.isUnlocked = false

        manager.handleAppleSignIn(.failure(ASAuthorizationError(.failed)))

        #expect(!manager.isSignedIn)
        #expect(!manager.isUnlocked)
    }

    // `unlockWithBiometrics()` is intentionally not covered here: it drives a live
    // LAContext policy evaluation, which depends on the runner's biometric enrollment
    // state and can block on a system prompt for minutes on machines with Face ID
    // simulation enabled. Not safe to run unattended in a general test suite.
}
