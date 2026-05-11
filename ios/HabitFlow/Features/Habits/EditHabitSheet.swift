import SwiftUI

struct EditHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    let habit: HabitItem
    let token: String
    let vm: HabitsViewModel

    @State private var name: String
    @State private var selectedCategory: HabitCategory
    @State private var description: String
    @State private var isLoading = false
    @State private var error: String?

    init(habit: HabitItem, token: String, vm: HabitsViewModel) {
        self.habit = habit
        self.token = token
        self.vm = vm
        _name = State(initialValue: habit.name)
        _selectedCategory = State(initialValue: HabitCategory(rawValue: habit.category) ?? .fitness)
        _description = State(initialValue: habit.description ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HFSpacing.s6) {

                    HFTextField(label: "Habit Name", text: $name)

                    VStack(alignment: .leading, spacing: HFSpacing.s3) {
                        Text("Category")
                            .font(Font.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.hfOnBackground)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: HFSpacing.s2) {
                            ForEach(HabitCategory.allCases, id: \.self) { cat in
                                categoryChip(cat)
                            }
                        }
                    }

                    HFTextField(label: "Description (optional)", text: $description)

                    if let error {
                        HFErrorBanner(message: error)
                    }

                    HFPrimaryButton(title: "Save Changes", action: save, isLoading: isLoading)
                }
                .padding(HFSpacing.s5)
            }
            .background(Color.hfBackground)
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                }
            }
        }
    }

    private func categoryChip(_ cat: HabitCategory) -> some View {
        let selected = selectedCategory == cat
        return Button { selectedCategory = cat } label: {
            VStack(spacing: HFSpacing.s1) {
                Image(systemName: cat.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(cat.rawValue.capitalized)
                    .font(.hfTiny)
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? cat.fg : Color.hfOnSurfaceVariant)
            .frame(maxWidth: .infinity)
            .padding(.vertical, HFSpacing.s3)
            .background(selected ? cat.bg : Color.hfSurfaceVariant)
            .clipShape(RoundedRectangle(cornerRadius: HFRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: HFRadius.md, style: .continuous)
                    .stroke(selected ? cat.fg.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Habit name cannot be empty."
            return
        }
        error = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await vm.updateHabit(
                    id: habit.id,
                    name: name.trimmingCharacters(in: .whitespaces),
                    category: selectedCategory.rawValue,
                    description: description.isEmpty ? nil : description,
                    token: token
                )
                dismiss()
            } catch let e as APIError {
                error = e.errorDescription
            } catch {
                self.error = "Failed to save changes."
            }
        }
    }
}
