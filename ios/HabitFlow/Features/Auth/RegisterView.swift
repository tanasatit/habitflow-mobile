import SwiftUI

struct RegisterView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero
                Group {
                    Text("HabitFlow").foregroundStyle(Color.hfPrimary) +
                    Text(" AI").foregroundStyle(Color.hfTertiary)
                }
                .font(.hfDisplay)
                .padding(.top, HFSpacing.s10)

                Text("Create your account")
                    .font(.hfBody)
                    .foregroundStyle(Color.hfOnSurfaceVariant)
                    .padding(.top, HFSpacing.s2)

                // Fields
                VStack(spacing: HFSpacing.s4) {
                    HFTextField(label: "Name", text: $name)
                    HFTextField(label: "Email", text: $email,
                                keyboard: .emailAddress, capitalization: .never)
                    HFTextField(label: "Password", text: $password, isSecure: true)
                }
                .padding(.top, HFSpacing.s8)

                // Password hint
                Text("Minimum 8 characters")
                    .font(.hfTiny)
                    .foregroundStyle(Color.hfOnSurfaceVariant)
                    .padding(.top, HFSpacing.s2)

                // Error
                if let error {
                    HFErrorBanner(message: error)
                        .padding(.top, HFSpacing.s4)
                }

                // Create account
                HFPrimaryButton(title: "Create Account", action: register, isLoading: auth.isLoading)
                    .padding(.top, HFSpacing.s6)

                // Back to login
                HStack {
                    Spacer()
                    Text("Already have an account? ")
                        .font(.hfBody)
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                    Button("Sign in") { dismiss() }
                        .font(Font.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.hfPrimary)
                    Spacer()
                }
                .padding(.top, HFSpacing.s6)
            }
            .padding(.horizontal, HFSpacing.s6)
            .padding(.bottom, HFSpacing.s8)
        }
        .background(Color.hfBackground)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.hfOnBackground)
                }
            }
        }
    }

    private func register() {
        guard !auth.isLoading else { return }
        error = nil
        Task {
            do {
                try await auth.register(name: name, email: email, password: password)
            } catch let apiError as APIError {
                error = apiError.errorDescription
            } catch {
                self.error = "Something went wrong. Please try again."
            }
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environment(AuthStore())
    }
}
