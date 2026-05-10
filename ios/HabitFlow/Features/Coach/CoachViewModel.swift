import SwiftUI

@MainActor
@Observable
final class CoachViewModel {
    var messages: [ChatMessage] = []
    var isTyping = false
    var error: String?

    private let api = APIClient.shared

    func send(_ text: String, token: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(role: .user, text: trimmed))
        isTyping = true
        error = nil

        do {
            let response: AIResponse = try await api.send(.aiChat(message: trimmed), token: token)
            isTyping = false
            messages.append(ChatMessage(role: .assistant, text: response.reply, events: response.events ?? []))
        } catch {
            isTyping = false
            self.error = "Couldn't reach AI Coach. Please try again."
        }
    }
}
