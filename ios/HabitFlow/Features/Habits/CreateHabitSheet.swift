import SwiftUI

struct CreateHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    let token: String
    let onCreated: () async -> Void

    @State private var name = ""
    @State private var selectedCategory: HabitCategory = .fitness
    @State private var description = ""
    @State private var isLoading = false
    @State private var error: String?

    private let vm = HabitsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HFSpacing.s6) {

                    HFTextField(label: "Habit Name", text: $name)

                    // Category picker
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

                    HFPrimaryButton(title: "Create Habit", action: create, isLoading: isLoading)
                }
                .padding(HFSpacing.s5)
            }
            .background(Color.hfBackground)
            .navigationTitle("New Habit")
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

    private func create() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Habit name cannot be empty."
            return
        }
        error = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await vm.createHabit(
                    name: name.trimmingCharacters(in: .whitespaces),
                    category: selectedCategory.rawValue,
                    description: description.isEmpty ? nil : description,
                    token: token
                )
                await onCreated()
                dismiss()
            } catch let e as APIError {
                error = e.errorDescription
            } catch {
                self.error = "Failed to create habit."
            }
        }
    }
}
