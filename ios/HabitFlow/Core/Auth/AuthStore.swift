import SwiftUI

@MainActor
@Observable
final class AuthStore {
    var user: User?
    var token: String?
    var isLoading = false

    var isAuthenticated: Bool { user != nil }

    private let api = APIClient.shared

    // Called once on app launch — restores session from keychain
    func tryAutoLogin() async {
        guard let saved = KeychainStore.loadToken() else { return }
        do {
            let me: User = try await api.send(.me, token: saved)
            self.token = saved
            self.user = me
        } catch {
            KeychainStore.deleteToken()
        }
    }

    func login(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        let response: AuthResponse = try await api.send(.login(email: email, password: password))
        persist(response)
    }

    func register(name: String, email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        let response: AuthResponse = try await api.send(.register(name: name, email: email, password: password))
        persist(response)
    }

    func logout() {
        Task {
            if let token { try? await api.sendVoid(.logout, token: token) }
            self.user = nil
            self.token = nil
            KeychainStore.deleteToken()
        }
    }

    private func persist(_ response: AuthResponse) {
        self.token = response.token
        self.user = response.user
        KeychainStore.saveToken(response.token)
    }
}
