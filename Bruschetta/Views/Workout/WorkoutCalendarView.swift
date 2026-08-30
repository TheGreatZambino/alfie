import SwiftUI
import SwiftData

struct WorkoutCalendarView: View {
    @Query(sort: \WorkoutSession.date) private var sessions: [WorkoutSession]
    @ObservedObject private var health = HealthKitManager.shared

    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var cardioWorkouts: [CardioWorkout] = []
    @State private var canGoToPreviousMonth = false
    @State private var isLoading = false

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 20) {
            monthHeader

            weekdayHeader

            calendarGrid

            legend

            Spacer()
        }
        .padding()
        .navigationTitle("Workout Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: displayedMonth) {
            await loadMonth()
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!canGoToPreviousMonth || isLoading)

            Spacer()

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrentMonth || isLoading)
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let counts = workoutCounts()
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let leadingEmpty = firstWeekday - 1

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
            ForEach(0..<(leadingEmpty + daysInMonth), id: \.self) { index in
                if index < leadingEmpty {
                    Color.clear.frame(height: 36)
                } else {
                    let day = index - leadingEmpty + 1
                    DayCell(day: day, count: counts[day] ?? 0, isToday: isToday(day))
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem { Circle().fill(Color(.systemGray5)).frame(width: 14, height: 14) } label: { "No workout" }
            legendItem { Circle().fill(Color.green).frame(width: 14, height: 14) } label: { "1 workout" }
            legendItem { Image(systemName: "star.fill").foregroundStyle(Color.workoutGold).font(.system(size: 14)) } label: { "2+ workouts" }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem<Symbol: View>(@ViewBuilder symbol: () -> Symbol, label: () -> String) -> some View {
        HStack(spacing: 6) {
            symbol()
            Text(label())
        }
    }

    private func isToday(_ day: Int) -> Bool {
        guard let date = calendar.date(bySetting: .day, value: day, of: displayedMonth) else { return false }
        return calendar.isDateInToday(date)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = newMonth
    }

    private func workoutCounts() -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for session in sessions where calendar.isDate(session.date, equalTo: displayedMonth, toGranularity: .month) {
            counts[calendar.component(.day, from: session.date), default: 0] += 1
        }
        for workout in cardioWorkouts {
            counts[calendar.component(.day, from: workout.startDate), default: 0] += 1
        }
        return counts
    }

    private func loadMonth() async {
        isLoading = true
        defer { isLoading = false }

        if let interval = calendar.dateInterval(of: .month, for: displayedMonth) {
            cardioWorkouts = await health.fetchWorkouts(in: interval)
        } else {
            cardioWorkouts = []
        }

        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else {
            canGoToPreviousMonth = false
            return
        }

        let hasLocalSession = sessions.contains { calendar.isDate($0.date, equalTo: previousMonth, toGranularity: .month) }
        if hasLocalSession {
            canGoToPreviousMonth = true
        } else if let previousInterval = calendar.dateInterval(of: .month, for: previousMonth) {
            let previousCardio = await health.fetchWorkouts(in: previousInterval)
            canGoToPreviousMonth = !previousCardio.isEmpty
        } else {
            canGoToPreviousMonth = false
        }
    }
}

private struct DayCell: View {
    let day: Int
    let count: Int
    let isToday: Bool

    var body: some View {
        ZStack {
            if count > 1 {
                Image(systemName: "star.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.workoutGold)
            } else {
                Circle()
                    .fill(count == 1 ? Color.green : Color(.systemGray5))
                    .frame(width: 32, height: 32)
            }
            Text("\(day)")
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(textColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var textColor: Color {
        if count > 1 { return .black }
        if count == 1 { return .white }
        return .primary
    }
}

private extension Color {
    static let workoutGold = Color(hex: "#D4AF37")
}
