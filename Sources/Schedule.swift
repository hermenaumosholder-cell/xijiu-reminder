import Foundation

struct Reminder: Codable, Equatable {
    let id: String
    let time: String
    let title: String
    let message: String
    let state: String
}

struct ScheduledReminder: Codable, Equatable {
    let reminder: Reminder
    let date: Date
    let key: String
}

struct Routine: Codable {
    let timezone: String
    let weekdays: [Reminder]
    let weekends: [Reminder]

    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timezone)!
        return cal
    }

    func events(on date: Date) -> [ScheduledReminder] {
        let cal = calendar
        let weekday = cal.component(.weekday, from: date)
        let items = (weekday == 1 || weekday == 7) ? weekends : weekdays
        let day = cal.dateComponents([.year, .month, .day], from: date)
        return items.compactMap { item in
            let parts = item.time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
            var components = day
            components.hour = parts[0]
            components.minute = parts[1]
            components.second = 0
            guard let eventDate = cal.date(from: components) else { return nil }
            let key = "\(day.year!)-\(day.month!)-\(day.day!):\(item.id)"
            return ScheduledReminder(reminder: item, date: eventDate, key: key)
        }.sorted { $0.date < $1.date }
    }

    func next(after date: Date) -> ScheduledReminder? {
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if let event = events(on: day).first(where: { $0.date > date }) { return event }
        }
        return nil
    }

    func due(at date: Date, delivered: Set<String>, grace: TimeInterval = 90) -> [ScheduledReminder] {
        events(on: date).filter {
            let delay = date.timeIntervalSince($0.date)
            return delay >= 0 && delay < grace && !delivered.contains($0.key)
        }
    }

    func validate() throws {
        guard TimeZone(identifier: timezone) != nil else { throw RoutineError.invalid("无效时区") }
        for items in [weekdays, weekends] {
            guard !items.isEmpty, Set(items.map(\.id)).count == items.count else {
                throw RoutineError.invalid("提醒编号必须唯一，时间表不能为空")
            }
            for item in items {
                let parts = item.time.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]), !item.title.isEmpty else {
                    throw RoutineError.invalid("无效提醒：\(item.id)")
                }
            }
        }
    }
}

enum RoutineError: Error { case invalid(String) }
