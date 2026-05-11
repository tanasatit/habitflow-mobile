import SwiftUI

struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    let token: String
    let defaultDate: Date
    let onCreate: (CreateEventRequest) async throws -> Void

    @State private var title = ""
    @State private var notes = ""
    @State private var category = ""
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var allDay = false
    @State private var isLoading = false
    @State private var error: String?

    private let categories = ["work", "health", "personal", "study", "social", "other"]

    init(token: String, defaultDate: Date, onCreate: @escaping (CreateEventRequest) async throws -> Void) {
        self.token = token
        self.defaultDate = defaultDate
        self.onCreate = onCreate
        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: defaultDate) ?? defaultDate
        _startAt = State(initialValue: start)
        _endAt   = State(initialValue: start.addingTimeInterval(3600))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Event title", text: $title)
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

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.hfPrimary)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
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
                let request = CreateEventRequest(
                    title: title.trimmingCharacters(in: .whitespaces),
                    notes: notes.isEmpty ? nil : notes,
                    category: category.isEmpty ? nil : category,
                    startAt: startAt,
                    endAt: allDay ? Calendar.current.date(byAdding: .day, value: 1, to: startAt)! : endAt,
                    allDay: allDay
                )
                try await onCreate(request)
                dismiss()
            } catch let e as APIError {
                error = e.errorDescription
            } catch {
                self.error = "Failed to create event."
            }
        }
    }
}
