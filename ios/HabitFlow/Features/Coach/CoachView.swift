import SwiftUI

// A saved conversation session
struct ChatSession: Identifiable {
    let id: UUID
    let title: String
    let date: Date
    let messages: [ChatMessage]

    init(messages: [ChatMessage]) {
        self.id = UUID()
        self.messages = messages
        self.date = Date()
        self.title = messages.first(where: { $0.role == .user })?.text
            .trimmingCharacters(in: .whitespaces)
            .prefix(40)
            .description ?? "New conversation"
    }
}

struct CoachView: View {
    @Environment(AuthStore.self) private var auth
    @State private var vm = CoachViewModel()
    @State private var draft = ""
    @State private var showSidebar = false
    @State private var sessions: [ChatSession] = []
    @FocusState private var inputFocused: Bool

    private let suggestions = ["Plan my week", "Build a morning routine", "Review my progress", "Add a gym habit"]

    var body: some View {
        ZStack(alignment: .leading) {
            // Main content (slides right when sidebar open)
            mainContent
                .offset(x: showSidebar ? 280 : 0)
                .animation(.easeOut(duration: 0.25), value: showSidebar)

            // Dim overlay
            if showSidebar {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .offset(x: 280)
                    .onTapGesture { withAnimation { showSidebar = false } }
                    .animation(.easeOut(duration: 0.25), value: showSidebar)
            }

            // Sidebar
            sidebar
                .frame(width: 280)
                .offset(x: showSidebar ? 0 : -280)
                .animation(.easeOut(duration: 0.25), value: showSidebar)
        }
        .background(Color.hfBackground)
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { withAnimation { showSidebar.toggle() } } label: {
                    VStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.hfOnBackground)
                                .frame(width: 20, height: 2)
                        }
                    }
                    .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: HFSpacing.s1) {
                    Text("Ask Flow.")
                        .font(.hfDisplay)
                        .foregroundStyle(Color.hfOnBackground)
                    Text("Your habit planning assistant")
                        .font(.hfTiny)
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                }
                Spacer()
                if !vm.messages.isEmpty {
                    Button {
                        saveCurrent()
                        vm.messages = []
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.hfOnSurfaceVariant)
                    }
                }
            }
            .padding(.horizontal, HFSpacing.s5)
            .padding(.vertical, HFSpacing.s4)
            .overlay(alignment: .bottom) { Divider() }

            if auth.user?.role == .free {
                paywallView
            } else {
                chatArea
                suggestionChips
                inputBar
            }
        }
        .background(Color.hfBackground)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sidebar header
            VStack(alignment: .leading, spacing: HFSpacing.s1) {
                Text("History")
                    .font(.hfH2)
                    .foregroundStyle(Color.hfOnBackground)
                Text("\(sessions.count) conversation\(sessions.count == 1 ? "" : "s")")
                    .font(.hfBodySmall)
                    .foregroundStyle(Color.hfOnSurfaceVariant)
            }
            .padding(.horizontal, HFSpacing.s5)
            .padding(.top, HFSpacing.s8 + HFSpacing.s4)
            .padding(.bottom, HFSpacing.s4)

            Divider()

            if sessions.isEmpty {
                VStack(spacing: HFSpacing.s2) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.hfOutline)
                    Text("No history yet")
                        .font(.hfBody)
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sessions) { session in
                            Button {
                                vm.messages = session.messages
                                withAnimation { showSidebar = false }
                            } label: {
                                VStack(alignment: .leading, spacing: HFSpacing.s1) {
                                    Text(session.title)
                                        .font(Font.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.hfOnBackground)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text(session.date, style: .relative)
                                        .font(.hfTiny)
                                        .foregroundStyle(Color.hfOnSurfaceVariant)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, HFSpacing.s5)
                                .padding(.vertical, HFSpacing.s3)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, HFSpacing.s5)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color.hfSurface)
        .overlay(alignment: .trailing) {
            Divider()
        }
    }

    // MARK: - Chat area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: HFSpacing.s3) {
                    if vm.messages.isEmpty { emptyState }
                    ForEach(vm.messages) { msg in
                        BubbleView(message: msg, userInitial: String(auth.user?.name.prefix(1) ?? "?"))
                            .id(msg.id)
                    }
                    if vm.isTyping {
                        TypingIndicator().id("typing")
                    }
                    if let error = vm.error {
                        HFErrorBanner(message: error).padding(.horizontal, HFSpacing.s4)
                    }
                }
                .padding(HFSpacing.s4)
            }
            .onChange(of: vm.messages.count) {
                let target = vm.messages.last.map { AnyHashable($0.id) } ?? AnyHashable("typing")
                withAnimation { proxy.scrollTo(target, anchor: .bottom) }
            }
            .onChange(of: vm.isTyping) {
                if vm.isTyping { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: HFSpacing.s3) {
            ZStack {
                Circle().fill(Color.hfTertiary.opacity(0.1)).frame(width: 56, height: 56)
                Image(systemName: "sparkles").font(.system(size: 26)).foregroundStyle(Color.hfTertiary)
            }
            Text("Tell me about your week")
                .font(.hfH3).foregroundStyle(Color.hfOnBackground)
            Text("I'll build a habit plan and schedule it on your calendar.")
                .font(.hfBodySmall).foregroundStyle(Color.hfOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, HFSpacing.s10)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Suggestion chips

    @ViewBuilder
    private var suggestionChips: some View {
        if vm.messages.isEmpty && !vm.isTyping {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HFSpacing.s2) {
                    ForEach(suggestions, id: \.self) { s in
                        Button { Task { await send(s) } } label: {
                            Text(s)
                                .font(Font.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.hfOnBackground)
                                .padding(.horizontal, HFSpacing.s4)
                                .padding(.vertical, HFSpacing.s2 + 2)
                                .background(Color.hfSurface)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.hfOutline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, HFSpacing.s4)
                .padding(.bottom, HFSpacing.s2)
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: HFSpacing.s2) {
            TextField("Describe your week…", text: $draft, axis: .vertical)
                .font(.system(size: 13))
                .lineLimit(1...4)
                .focused($inputFocused)

            Button { Task { await send(draft) } } label: {
                Text("SEND")
                    .font(.hfLabelStrong)
                    .foregroundStyle(.white)
                    .padding(.horizontal, HFSpacing.s4)
                    .padding(.vertical, HFSpacing.s2 + 2)
                    .background(
                        Color.hfPrimary.opacity(
                            draft.trimmingCharacters(in: .whitespaces).isEmpty || vm.isTyping ? 0.4 : 1
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: HFRadius.md, style: .continuous))
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || vm.isTyping)
        }
        .padding(.horizontal, HFSpacing.s4)
        .padding(.vertical, HFSpacing.s3)
        .overlay(Divider(), alignment: .top)
        .background(Color.hfBackground)
    }

    // MARK: - Paywall

    private var paywallView: some View {
        VStack(spacing: HFSpacing.s5) {
            Spacer()
            ZStack {
                Circle().fill(Color.hfPrimary.opacity(0.1)).frame(width: 72, height: 72)
                Image(systemName: "sparkles").font(.system(size: 32)).foregroundStyle(Color.hfPrimary)
            }
            VStack(spacing: HFSpacing.s2) {
                Text("AI Coach").font(.hfH2).foregroundStyle(Color.hfOnBackground)
                Text("Get a personal habit coach powered by AI. Plan your week, build routines, and stay on track.")
                    .font(.hfBody).foregroundStyle(Color.hfOnSurfaceVariant).multilineTextAlignment(.center)
            }
            HFPrimaryButton(title: "Upgrade to Premium") { }
                .padding(.horizontal, HFSpacing.s8)
            Spacer()
        }
        .padding(HFSpacing.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func send(_ text: String) async {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        draft = ""
        inputFocused = false
        await vm.send(t, token: auth.token ?? "")
    }

    private func saveCurrent() {
        guard !vm.messages.isEmpty else { return }
        sessions.insert(ChatSession(messages: vm.messages), at: 0)
    }
}

// MARK: - Chat bubble

struct BubbleView: View {
    let message: ChatMessage
    let userInitial: String
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: HFSpacing.s2) {
            if isUser { Spacer(minLength: HFSpacing.s10) }
            if !isUser { avatar }

            Text(message.text)
                .font(.system(size: 13)).lineSpacing(3)
                .foregroundStyle(isUser ? .white : Color.hfOnBackground)
                .padding(.horizontal, 13).padding(.vertical, 10)
                .background(isUser ? Color.hfPrimary : Color.hfSurface)
                .clipShape(.rect(
                    topLeadingRadius: isUser ? HFRadius.lg : 4,
                    bottomLeadingRadius: HFRadius.lg,
                    bottomTrailingRadius: HFRadius.lg,
                    topTrailingRadius: isUser ? 4 : HFRadius.lg
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: HFRadius.lg)
                        .stroke(Color.hfOutline, lineWidth: isUser ? 0 : 1)
                )

            if isUser { avatar }
            else { Spacer(minLength: HFSpacing.s10) }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(isUser ? Color.hfPrimary.opacity(0.1) : Color.hfTertiary.opacity(0.1))
                .frame(width: 30, height: 30)
            if isUser {
                Text(userInitial)
                    .font(Font.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.hfPrimary)
            } else {
                Image(systemName: "cpu").font(.system(size: 14)).foregroundStyle(Color.hfTertiary)
            }
        }
    }
}

// MARK: - Typing indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: HFSpacing.s2) {
            ZStack {
                Circle().fill(Color.hfTertiary.opacity(0.1)).frame(width: 30, height: 30)
                Image(systemName: "cpu").font(.system(size: 14)).foregroundStyle(Color.hfTertiary)
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.hfOnSurfaceVariant)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animating ? 1 : 0.5)
                        .opacity(animating ? 1 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color.hfSurface)
            .clipShape(.rect(topLeadingRadius: 4, bottomLeadingRadius: HFRadius.lg,
                             bottomTrailingRadius: HFRadius.lg, topTrailingRadius: HFRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: HFRadius.lg).stroke(Color.hfOutline, lineWidth: 1))
            .onAppear { animating = true }
            Spacer()
        }
    }
}

#Preview {
    CoachView().environment(AuthStore())
}
