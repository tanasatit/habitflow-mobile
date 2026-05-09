import SwiftUI

struct HabitRowView: View {
    let item: TodayHabitItem
    let onToggle: () -> Void

    private var category: HabitCategory? { HabitCategory(rawValue: item.habit.category) }

    var body: some View {
        HStack(spacing: HFSpacing.s3) {
            // Category icon chip
            ZStack {
                RoundedRectangle(cornerRadius: HFRadius.md, style: .continuous)
                    .fill(category?.bg ?? Color.hfSurfaceVariant)
                    .frame(width: 38, height: 38)
                Image(systemName: category?.icon ?? "star.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(category?.fg ?? Color.hfOnSurfaceVariant)
            }

            // Name + category label
            VStack(alignment: .leading, spacing: 2) {
                Text(item.habit.name)
                    .font(Font.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.completedToday ? Color.hfOnSurfaceVariant : Color.hfOnBackground)
                    .strikethrough(item.completedToday, color: Color.hfOnSurfaceVariant)
                    .lineLimit(1)
                Text(item.habit.category.capitalized)
                    .font(.hfTiny)
                    .foregroundStyle(Color.hfOnSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Streak badge
            if item.currentStreak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.hfPrimary)
                    Text("\(item.currentStreak)")
                        .font(Font.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color.hfPrimary)
                }
            }

            // Toggle button
            Button(action: onToggle) {
                ZStack {
                    if item.completedToday {
                        Circle()
                            .fill(Color.hfTertiary)
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .stroke(Color.hfOutline, lineWidth: 2)
                            .frame(width: 26, height: 26)
                    }
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: item.completedToday)
        }
        .padding(HFSpacing.s3)
        .background(Color.hfSurface)
        .clipShape(RoundedRectangle(cornerRadius: HFRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HFRadius.xl, style: .continuous)
                .stroke(Color.hfOutline, lineWidth: 1)
        )
        .opacity(item.completedToday ? 0.65 : 1)
        .animation(.easeOut(duration: 0.2), value: item.completedToday)
    }
}
