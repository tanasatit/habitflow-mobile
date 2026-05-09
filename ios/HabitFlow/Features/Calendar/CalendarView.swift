import SwiftUI

struct CalendarView: View {
    @Environment(AuthStore.self) private var auth
    @State private var vm = CalendarViewModel()
    @State private var selectedDay = Date()
    @State private var weekDays: [Date] = CalendarViewModel.weekDays(containing: Date())
    @State private var showAddEvent = false

    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
    private let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            dayStrip
                .overlay(alignment: .bottom) { Divider() }
            eventList
        }
        .background(Color.hfBackground)
        .task { await vm.load(weekContaining: selectedDay, token: auth.token ?? "") }
        .refreshable { await vm.load(weekContaining: selectedDay, token: auth.token ?? "") }
        .sheet(isPresented: $showAddEvent) {
            AddEventSheet(token: auth.token ?? "", defaultDate: selectedDay) { request in
                try await vm.createEvent(request, token: auth.token ?? "")
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: HFSpacing.s1) {
                Text(monthFormatter.string(from: selectedDay).uppercased())
                    .font(.hfLabelStrong)
                    .foregroundStyle(Color.hfOnSurfaceVariant)
                Text("This Week.")
                    .font(.hfDisplay)
                    .foregroundStyle(Color.hfOnBackground)
            }
            Spacer()
            Button { showAddEvent = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.hfPrimary)
                    .clipShape(Circle())
                    .shadow(color: Color.hfPrimary.opacity(0.35), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, HFSpacing.s5)
        .padding(.top, HFSpacing.s4)
        .padding(.bottom, HFSpacing.s3)
    }

    // MARK: - Day strip

    private var dayStrip: some View {
        HStack(spacing: HFSpacing.s2) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { i, day in
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                let hasEvents = !vm.events(for: day).isEmpty

                Button { selectedDay = day } label: {
                    VStack(spacing: HFSpacing.s1) {
                        Text(dayLetters[i])
                            .font(Font.system(size: 10, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.hfOnSurfaceVariant)
                        Text(dayFormatter.string(from: day))
                            .font(Font.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(isSelected ? .white : Color.hfOnBackground)
                        Circle()
                            .fill(hasEvents ? (isSelected ? Color.white : Color.hfPrimary) : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HFSpacing.s2 + 2)
                    .background(isSelected ? Color.hfPrimary : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: HFRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .animation(.easeOut(duration: 0.15), value: isSelected)
            }
        }
        .padding(.horizontal, HFSpacing.s4)
        .padding(.bottom, HFSpacing.s4)
    }

    // MARK: - Event list

    private var eventList: some View {
        ScrollView {
            let dayEvents = vm.events(for: selectedDay)
            VStack(alignment: .leading, spacing: 0) {
                if vm.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = vm.error {
                    HFErrorBanner(message: error).padding(HFSpacing.s5)
                } else if dayEvents.isEmpty {
                    emptyState
                } else {
                    Text("\(dayEvents.count) event\(dayEvents.count == 1 ? "" : "s")")
                        .font(.hfLabelStrong)
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                        .padding(.horizontal, HFSpacing.s5)
                        .padding(.top, HFSpacing.s4)
                        .padding(.bottom, HFSpacing.s3)

                    ForEach(dayEvents) { event in
                        EventRow(event: event, timeFormatter: timeFormatter)
                            .padding(.horizontal, HFSpacing.s5)
                            .padding(.bottom, HFSpacing.s3)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await vm.deleteEvent(id: event.id, token: auth.token ?? "") }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding(.bottom, HFSpacing.s8)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: HFSpacing.s3) {
            ZStack {
                Circle()
                    .fill(Color.hfSurfaceVariant)
                    .frame(width: 56, height: 56)
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.hfOnSurfaceVariant)
            }
            Text("Nothing scheduled")
                .font(.hfH3)
                .foregroundStyle(Color.hfOnBackground)
            Text("Tap + to add an event, or ask the AI Coach to plan your day.")
                .font(.hfBodySmall)
                .foregroundStyle(Color.hfOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HFSpacing.s10)
        .padding(.horizontal, HFSpacing.s8)
    }
}

// MARK: - Event row

struct EventRow: View {
    let event: CalendarEvent
    let timeFormatter: DateFormatter

    var body: some View {
        HStack(alignment: .top, spacing: HFSpacing.s3) {
            // Time gutter
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeFormatter.string(from: event.startAt))
                    .font(Font.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.hfOnBackground)
                if !event.allDay {
                    let mins = Int(event.endAt.timeIntervalSince(event.startAt) / 60)
                    Text("\(mins) min")
                        .font(.hfTiny)
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                }
            }
            .frame(width: 60, alignment: .trailing)

            // Card
            HStack(spacing: HFSpacing.s3) {
                VStack(alignment: .leading, spacing: HFSpacing.s1) {
                    Text(event.title)
                        .font(Font.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.hfOnBackground)
                    if let notes = event.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.hfBodySmall)
                            .foregroundStyle(Color.hfOnSurfaceVariant)
                            .lineLimit(1)
                    }
                    HStack(spacing: HFSpacing.s1) {
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                        Text("Manual")
                            .font(Font.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.hfPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(HFSpacing.s3)
            .background(Color.hfSurface)
            .clipShape(RoundedRectangle(cornerRadius: HFRadius.lg, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.hfPrimary)
                    .frame(width: 3)
            }
            .overlay(
                RoundedRectangle(cornerRadius: HFRadius.lg, style: .continuous)
                    .stroke(Color.hfOutline, lineWidth: 1)
            )
        }
    }
}

#Preview {
    CalendarView()
        .environment(AuthStore())
}
