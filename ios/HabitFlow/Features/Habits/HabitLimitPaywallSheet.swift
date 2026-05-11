import SwiftUI

struct HabitLimitPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: HFSpacing.s5) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.hfPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.hfPrimary)
            }

            VStack(spacing: HFSpacing.s2) {
                Text("You've hit the free limit")
                    .font(.hfH2)
                    .foregroundStyle(Color.hfOnBackground)
                Text("Free accounts can track up to 5 habits. Upgrade to Premium to add unlimited habits and unlock the AI Coach.")
                    .font(.hfBody)
                    .foregroundStyle(Color.hfOnSurfaceVariant)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: HFSpacing.s3) {
                featureRow(icon: "infinity", text: "Unlimited habits")
                featureRow(icon: "sparkles", text: "AI habit coach")
                featureRow(icon: "chart.bar.fill", text: "Advanced insights")
            }
            .padding(.horizontal, HFSpacing.s4)

            HFPrimaryButton(title: "Upgrade to Premium") { }
                .padding(.horizontal, HFSpacing.s8)

            Button("Maybe later") { dismiss() }
                .font(Font.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.hfOnSurfaceVariant)

            Spacer()
        }
        .padding(HFSpacing.s6)
        .background(Color.hfBackground)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: HFSpacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.hfTertiary)
                .frame(width: 24)
            Text(text)
                .font(.hfBody)
                .foregroundStyle(Color.hfOnBackground)
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.hfTertiary)
        }
    }
}
