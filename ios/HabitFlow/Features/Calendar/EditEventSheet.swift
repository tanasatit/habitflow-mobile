import SwiftUI

struct EditEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    let event: CalendarEvent
    let onUpdate: (UpdateEventRequest) async throws -> Void
    let onDelete: () async -> Void

    @State private var title: String
    @State private var notes: String
    @State private var category: String
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var allDay: Bool
    @State private var isLoading = false
    @State private var showDeleteConfirm = false
    @State private var error: String?

    private let categories = ["work", "health", "personal", "study", "social", "other"]

    init(event: CalendarEvent, onUpdate: @escaping (UpdateEventRequest) async throws -> Void, onDelete: @escaping () async -> Void) {
        self.event = event
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _title = State(initialValue: event.title)
        _notes = State(initialValue: event.notes ?? "")
        _category = State(initialValue: event.category ?? "")
        _startAt = State(initialValue: event.startAt)
        _endAt = State(initialValue: event.endAt)
        _allDay = State(initialValue: event.allDay)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HFTextField(label: "Title", text: $title)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal, HFSpacing.s5)
                        .padding(.vertical, HFSpacing.s2)
                }

                Section {
                    Toggle("All Day", isOn: $allDay)
                    DatePicker("Start", selection: $startAt,
                               displayedComponents: allDay ? .date : [.date, .hourAndMinute])
                    DatePicker("End", selection: $endAt,
                               in: startAt...,
                               displayedComponents: allDay ? .date : [.date, .hourAndMinute])
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        Text("None").tag("")
                        ForEach(categories, id: \.self) { cat in
                            Text(cat.capitalized).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    HFTextField(label: "Notes (optional)", text: $notes)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal, HFSpacing.s5)
                        .padding(.vertical, HFSpacing.s2)
                }

                Section {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        HStack {
                            Spacer()
                            Text("Delete Event")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }

                if let error {
                    Section {
                        HFErrorBanner(message: error)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.hfBackground)
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.hfPrimary)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .confirmationDialog("Delete this event?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        await onDelete()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Title cannot be empty."
            return
        }
        error = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let request = UpdateEventRequest(
                    title: title.trimmingCharacters(in: .whitespaces),
                    notes: notes.isEmpty ? nil : notes,
                    category: category.isEmpty ? nil : category,
                    startAt: startAt,
                    endAt: allDay ? Calendar.current.date(byAdding: .day, value: 1, to: startAt)! : endAt,
                    allDay: allDay
                )
                try await onUpdate(request)
                dismiss()
            } catch let e as APIError {
                error = e.errorDescription
            } catch {
                self.error = "Failed to update event."
            }
        }
    }
}
