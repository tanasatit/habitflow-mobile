import SwiftUI

struct HabitsView: View {
    @Environment(AuthStore.self) private var auth
    @State private var vm = HabitsViewModel()
    @State private var showCreate = false
    @State private var habitToEdit: HabitItem?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: HFSpacing.s1) {
                        Text("Your Oasis.")
                            .font(.hfDisplay)
                            .foregroundStyle(Color.hfOnBackground)
                        Text("\(vm.habits.count) habit\(vm.habits.count == 1 ? "" : "s") tracked")
                            .font(.hfBodySmall)
                            .foregroundStyle(Color.hfOnSurfaceVariant)
                    }
                    Spacer()
                    Button { showCreate = true } label: {
                        HStack(spacing: HFSpacing.s1) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Add")
                                .font(Font.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, HFSpacing.s4)
                        .padding(.vertical, 10)
                        .background(Color.hfPrimary)
                        .clipShape(Capsule())
                        .shadow(color: Color.hfPrimary.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.top, HFSpacing.s4)
                .padding(.bottom, HFSpacing.s5)

                if vm.isLoading && vm.habits.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = vm.error {
                    HFErrorBanner(message: error)
                } else {
                    LazyVGrid(columns: columns, spacing: HFSpacing.s3) {
                        ForEach(vm.habits) { habit in
                            BentoCard(habit: habit, stats: vm.stats[habit.id])
                                .contextMenu {
                                    Button {
                                        habitToEdit = habit
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        Task { await vm.deleteHabit(id: habit.id, token: auth.token ?? "") }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        // Dashed "add" card
                        Button { showCreate = true } label: {
                            VStack(spacing: HFSpacing.s2) {
                                Image(systemName: "plus")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.hfOnSurfaceVariant)
                                Text("New Habit")
                                    .font(Font.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.hfOnSurfaceVariant)
                            }
                            .frame(maxWidth: .infinity, minHeight: 144)
                            .background(Color.hfBackground)
                            .clipShape(RoundedRectangle(cornerRadius: HFRadius.xxl, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: HFRadius.xxl, style: .continuous)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                                    .foregroundStyle(Color.hfOutline)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, HFSpacing.s5)
            .padding(.bottom, HFSpacing.s8)
        }
        .background(Color.hfBackground)
        .task { await vm.load(token: auth.token ?? "") }
        .refreshable { await vm.load(token: auth.token ?? "") }
        .sheet(isPresented: $showCreate) {
            CreateHabitSheet(token: auth.token ?? "") {
                await vm.load(token: auth.token ?? "")
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $habitToEdit) { habit in
            EditHabitSheet(habit: habit, token: auth.token ?? "", vm: vm)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Bento card

struct BentoCard: View {
    let habit: HabitItem
    let stats: HabitStats?

    private var category: HabitCategory? { HabitCategory(rawValue: habit.category) }
    private var streak: Int { stats?.currentStreak ?? 0 }
    private var pct: Int { min(100, Int((stats?.completionRate ?? 0) * 100)) }

    var body: some View {
        HFCard {
            VStack(alignment: .leading, spacing: HFSpacing.s3) {
                // Icon + category badge
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: HFRadius.md, style: .continuous)
                            .fill(category?.bg ?? Color.hfSurfaceVariant)
                            .frame(width: 34, height: 34)
                        Image(systemName: category?.icon ?? "star.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(category?.fg ?? Color.hfOnSurfaceVariant)
                    }
                    Spacer()
                    Text(habit.category.capitalized)
                        .font(.hfTiny)
                        .fontWeight(.medium)
                        .foregroundStyle(category?.fg ?? Color.hfOnSurfaceVariant)
                        .padding(.horizontal, HFSpacing.s2)
                        .padding(.vertical, 3)
                        .background(category?.bg ?? Color.hfSurfaceVariant)
                        .clipShape(Capsule())
                }

                // Name
                Text(habit.name)
                    .font(Font.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.hfOnBackground)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                // Streak + completion %
                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.hfPrimary)
                        Text("\(streak) day streak")
                            .font(Font.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundStyle(Color.hfPrimary)
                    }
                    Spacer()
                    Text("\(pct)%")
                        .font(.hfTiny)
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                }
            }
            .padding(HFSpacing.s4)
            .frame(minHeight: 144, alignment: .top)
            // Progress bar pinned to bottom
            .overlay(alignment: .bottom) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.hfSurfaceVariant)
                            .frame(height: 4)
                        Rectangle()
                            .fill(Color.hfTertiary)
                            .frame(width: geo.size.width * CGFloat(pct) / 100, height: 4)
                            .clipShape(
                                .rect(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                      bottomTrailingRadius: 4, topTrailingRadius: 4)
                            )
                    }
                }
                .frame(height: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: HFRadius.xxl, style: .continuous))
        }
    }
}

#Preview {
    HabitsView()
        .environment(AuthStore())
}
