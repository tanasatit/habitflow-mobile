import SwiftUI

// MARK: - Card

struct HFCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(Color.hfSurface)
            .clipShape(RoundedRectangle(cornerRadius: HFRadius.xxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: HFRadius.xxl, style: .continuous)
                    .stroke(Color.hfOutline, lineWidth: 1)
            )
    }
}

// MARK: - Primary button (pill, orange)

struct HFPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: HFSpacing.s2) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                }
                Text(title)
                    .font(Font.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.hfPrimary)
            .clipShape(Capsule())
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1)
    }
}

// MARK: - Secondary button (pill, surface-variant)

struct HFSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Font.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.hfOnSurfaceVariant)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.hfSurfaceVariant)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Text link button (tertiary teal)

struct HFTextLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.hfBody)
                .foregroundStyle(Color.hfTertiary)
                .underline(false)
        }
    }
}

// MARK: - Pulsing flame modifier (2s scale, brand signature motion)

struct PulsingFlame: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.06 : 1.0)
            .opacity(pulsing ? 0.92 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2).repeatForever(autoreverses: true)
                ) { pulsing = true }
            }
    }
}

extension View {
    func pulsingFlame() -> some View {
        modifier(PulsingFlame())
    }
}

// MARK: - Section header

struct HFSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.hfH3)
                .foregroundStyle(Color.hfOnBackground)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.hfBodySmall)
                        .foregroundStyle(Color.hfTertiary)
                }
            }
        }
    }
}

// MARK: - Error banner

struct HFErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: HFSpacing.s3) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.hfDanger)
            Text(message)
                .font(.hfBodySmall)
                .foregroundStyle(Color.hfDanger)
        }
        .padding(HFSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hfDangerBg)
        .clipShape(RoundedRectangle(cornerRadius: HFRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HFRadius.md, style: .continuous)
                .stroke(Color.hfDangerBorder, lineWidth: 1)
        )
    }
}

// MARK: - Paywall card (free-tier gate)

struct HFPaywallCard: View {
    var body: some View {
        HFCard {
            VStack(alignment: .leading, spacing: HFSpacing.s3) {
                HStack(spacing: HFSpacing.s2) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.hfPrimary)
                    Text("Premium Feature")
                        .font(.hfH3)
                        .foregroundStyle(Color.hfOnBackground)
                }
                Text("Upgrade to Premium to unlock the AI Coach and unlimited habits.")
                    .font(.hfBody)
                    .foregroundStyle(Color.hfOnSurfaceVariant)
                HFPrimaryButton(title: "Upgrade to Premium") { }
            }
            .padding(HFSpacing.s5)
        }
    }
}

// MARK: - Progress ring

struct HFProgressRing: View {
    let color: Color
    let progress: Double  // 0–1
    let label: String
    let valueText: String
    var size: CGFloat = 72
    var strokeWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.hfOutline, lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)

            VStack(spacing: 0) {
                Text(valueText)
                    .font(Font.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.hfOnBackground)
                Text(label)
                    .font(.hfTiny)
                    .foregroundStyle(Color.hfOnSurfaceVariant)
            }
        }
        .frame(width: size, height: size)
    }
}
