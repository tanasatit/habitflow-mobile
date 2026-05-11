import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Wordmark hero
                    Group {
                        Text("HabitFlow").foregroundStyle(Color.hfPrimary) +
                        Text(" AI").foregroundStyle(Color.hfTertiary)
                    }
                    .font(.hfDisplay)
                    .padding(.top, HFSpacing.s10)

                    Text("Welcome back")
                        .font(.hfBody)
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                        .padding(.top, HFSpacing.s2)

                    // Fields
                    VStack(spacing: HFSpacing.s4) {
                        HFTextField(label: "Email", text: $email,
                                    keyboard: .emailAddress, capitalization: .never)
                        HFTextField(label: "Password", text: $password, isSecure: true)
                    }
                    .padding(.top, HFSpacing.s8)

                    // Error
                    if let error {
                        HFErrorBanner(message: error)
                            .padding(.top, HFSpacing.s4)
                    }

                    // Sign in
                    HFPrimaryButton(title: "Sign In", action: signIn, isLoading: auth.isLoading)
                        .padding(.top, HFSpacing.s6)

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(Color.hfOutline)
                        Text("OR").font(.hfTiny).foregroundStyle(Color.hfOnSurfaceVariant)
                            .padding(.horizontal, HFSpacing.s2)
                        Rectangle().frame(height: 1).foregroundStyle(Color.hfOutline)
                    }
                    .padding(.vertical, HFSpacing.s6)

                    // Create account
                    HStack {
                        Spacer()
                        Text("No account? ")
                            .font(.hfBody)
                            .foregroundStyle(Color.hfOnSurfaceVariant)
                        Button("Create one") { showRegister = true }
                            .font(Font.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.hfPrimary)
                        Spacer()
                    }
                }
                .padding(.horizontal, HFSpacing.s6)
                .padding(.bottom, HFSpacing.s8)
            }
            .background(Color.hfBackground)
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }

    private func signIn() {
        guard !auth.isLoading else { return }
        error = nil
        Task {
            do {
                try await auth.login(email: email, password: password)
            } catch let apiError as APIError {
                error = apiError.errorDescription
            } catch {
                self.error = "Something went wrong. Please try again."
            }
        }
    }
}

// MARK: - Reusable text field

struct HFTextField: View {
    let label: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: HFSpacing.s2) {
            Text(label)
                .font(Font.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.hfOnBackground)

            ZStack(alignment: .trailing) {
                Group {
                    if isSecure && !revealed {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                            .keyboardType(keyboard)
                            .textInputAutocapitalization(isSecure ? .never : capitalization)
                            .autocorrectionDisabled()
                    }
                }
                .font(.system(size: 15))
                .padding(.horizontal, HFSpacing.s4)
                .padding(.trailing, isSecure ? 40 : 0)
                .padding(.vertical, 13)

                if isSecure {
                    Button { revealed.toggle() } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.hfOnSurfaceVariant)
                    }
                    .padding(.trailing, HFSpacing.s4)
                }
            }
            .background(Color.hfSurface)
            .clipShape(RoundedRectangle(cornerRadius: HFRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: HFRadius.md, style: .continuous)
                    .stroke(Color.hfOutline, lineWidth: 1)
            )
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthStore())
}
