import SwiftUI

struct CalendarView: View {
    @Environment(AuthStore.self) private var auth
    @State private var vm = CalendarViewModel()
    @State private var selectedDay = Date()
    @State private var weekOffset = 0          // 0 = current week, -1 = last week, +1 = next week
    @State private var showAddEvent = false
    @State private var showMonthView = false

    private var weekDays: [Date] { CalendarViewModel.weekDays(containing: referenceDate) }
    private var referenceDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date()
    }

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            weekStrip
                .overlay(alignment: .bottom) { Divider() }
            eventList
        }
        .background(Color.hfBackground)
        .task { await loadCurrentWeek() }
        .onChange(of: weekOffset) { Task { await loadCurrentWeek() } }
        .refreshable { await loadCurrentWeek() }
        .onReceive(NotificationCenter.default.publisher(for: .calendarDidUpdate)) { _ in
            Task { await loadCurrentWeek() }
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventSheet(token: auth.token ?? "", defaultDate: selectedDay) { request in
                try await vm.createEvent(request, token: auth.token ?? "")
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showMonthView) {
            MonthPickerSheet(selectedDay: $selectedDay, events: vm.events) { day in
                selectedDay = day
                let newOffset = weeksFrom(Date(), to: day)
                if weekOffset != newOffset {
                    weekOffset = newOffset
                }
                showMonthView = false
            }
        }
    }

    private func loadCurrentWeek() async {
        // Auto-select today when navigating to current week
        if weekOffset == 0 { selectedDay = Date() }
        await vm.load(weekContaining: referenceDate, token: auth.token ?? "")
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            Button { showMonthView = true } label: {
                VStack(alignment: .leading, spacing: HFSpacing.s1) {
                    Text(monthFormatter.string(from: selectedDay).uppercased())
                        .font(.hfLabelStrong)
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                    HStack(spacing: HFSpacing.s1) {
                        Text("This Week.")
                            .font(.hfDisplay)
                            .foregroundStyle(Color.hfOnBackground)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.hfOnSurfaceVariant)
                            .padding(.top, 12)
                    }
                }
            }
            .buttonStyle(.plain)
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

    // MARK: - Week strip (swipeable)

    private var weekStrip: some View {
        VStack(spacing: HFSpacing.s3) {
            // Week navigation
            HStack {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { weekOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                        .frame(width: 28, height: 28)
                }
                Spacer()
                if weekOffset != 0 {
                    Button("Today") {
                        withAnimation(.easeOut(duration: 0.2)) {
                            weekOffset = 0
                            selectedDay = Date()
                        }
                    }
                    .font(Font.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.hfTertiary)
                }
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { weekOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.hfOnSurfaceVariant)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, HFSpacing.s4)

            // Day chips
            HStack(spacing: HFSpacing.s2) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { i, day in
                    dayChip(day: day, letter: dayLetters[i])
                }
            }
            .padding(.horizontal, HFSpacing.s4)
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { val in
                        withAnimation(.easeOut(duration: 0.2)) {
                            if val.translation.width < 0 { weekOffset += 1 }
                            else { weekOffset -= 1 }
                        }
                    }
            )
        }
        .padding(.bottom, HFSpacing.s3)
    }

    private func dayChip(day: Date, letter: String) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let isToday    = cal.isDateInToday(day)
        let hasEvents  = !vm.events(for: day).isEmpty

        return Button { selectedDay = day } label: {
            VStack(spacing: HFSpacing.s1) {
                Text(letter)
                    .font(Font.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.hfOnSurfaceVariant)
                ZStack {
                    Text(dayFormatter.string(from: day))
                        .font(Font.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(isSelected ? .white : isToday ? Color.hfPrimary : Color.hfOnBackground)
                    // Today ring (when not selected)
                    if isToday && !isSelected {
                        Circle()
                            .stroke(Color.hfPrimary, lineWidth: 1.5)
                            .frame(width: 30, height: 30)
                    }
                }
                // Event dot
                Circle()
                    .fill(hasEvents ? (isSelected ? Color.white : Color.hfDanger) : Color.clear)
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

    // MARK: - Event list

    private var eventList: some View {
        ScrollView {
            let dayEvents = vm.events(for: selectedDay)
            LazyVStack(alignment: .leading, spacing: 0) {
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

    // MARK: - Helpers

    private func weeksFrom(_ from: Date, to: Date) -> Int {
        Calendar.current.dateComponents([.weekOfYear], from: from, to: to).weekOfYear ?? 0
    }
}

// MARK: - Month picker sheet

struct MonthPickerSheet: View {
    @Binding var selectedDay: Date
    let events: [CalendarEvent]
    let onSelect: (Date) -> Void

    @State private var displayMonth = Date()

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
    private let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: HFSpacing.s4) {
                // Month navigation
                HStack {
                    Button {
                        displayMonth = cal.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Color.hfOnBackground)
                    }
                    Spacer()
                    Text(monthFormatter.string(from: displayMonth))
                        .font(.hfH3)
                        .foregroundStyle(Color.hfOnBackground)
                    Spacer()
                    Button {
                        displayMonth = cal.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.hfOnBackground)
                    }
                }
                .padding(.horizontal, HFSpacing.s5)

                // Day of week headers
                HStack {
                    ForEach(dayLetters, id: \.self) { l in
                        Text(l)
                            .font(Font.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.hfOnSurfaceVariant)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, HFSpacing.s4)

                // Calendar grid
                LazyVGrid(columns: columns, spacing: HFSpacing.s2) {
                    ForEach(monthDays(), id: \.self) { date in
                        if let date {
                            monthDayCell(date)
                        } else {
                            Color.clear.frame(height: 36)
                        }
                    }
                }
                .padding(.horizontal, HFSpacing.s4)

                Spacer()
            }
            .padding(.top, HFSpacing.s5)
            .background(Color.hfBackground)
            .navigationTitle("Pick a Day")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func monthDayCell(_ date: Date) -> some View {
        let isSelected = cal.isDate(date, inSameDayAs: selectedDay)
        let isToday    = cal.isDateInToday(date)
        let hasEvents  = events.contains { cal.isDate($0.startAt, inSameDayAs: date) }
        let isCurrentMonth = cal.isDate(date, equalTo: displayMonth, toGranularity: .month)

        return Button { onSelect(date) } label: {
            ZStack {
                if isSelected {
                    Circle().fill(Color.hfPrimary)
                } else if isToday {
                    Circle().stroke(Color.hfPrimary, lineWidth: 1.5)
                }
                VStack(spacing: 1) {
                    Text(String(cal.component(.day, from: date)))
                        .font(Font.system(size: 14, weight: isToday || isSelected ? .bold : .regular, design: .rounded))
                        .foregroundStyle(
                            isSelected ? .white :
                            isToday ? Color.hfPrimary :
                            isCurrentMonth ? Color.hfOnBackground : Color.hfOnSurfaceVariant.opacity(0.4)
                        )
                    if hasEvents {
                        Circle()
                            .fill(isSelected ? Color.white : Color.hfDanger)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(height: 36)
        }
        .buttonStyle(.plain)
    }

    private func monthDays() -> [Date?] {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.year, .month], from: displayMonth)
        guard let firstDay = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstDay) else { return [] }

        let weekday = (cal.component(.weekday, from: firstDay) + 5) % 7 // Mon=0
        var days: [Date?] = Array(repeating: nil, count: weekday)
        for d in range {
            days.append(cal.date(byAdding: .day, value: d - 1, to: firstDay))
        }
        return days
    }
}

// MARK: - Event row

struct EventRow: View {
    let event: CalendarEvent
    let timeFormatter: DateFormatter

    var body: some View {
        HStack(alignment: .top, spacing: HFSpacing.s3) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(event.allDay ? "All day" : timeFormatter.string(from: event.startAt))
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
