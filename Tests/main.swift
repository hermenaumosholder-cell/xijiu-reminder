import Foundation

let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let routine = try JSONDecoder().decode(Routine.self, from: data)
try routine.validate()
let formatter = ISO8601DateFormatter()
func date(_ value: String) -> Date { formatter.date(from:value)! }
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
let tuesday = date("2026-09-15T00:00:00Z")
let saturday = date("2026-09-19T00:00:00Z")
check(routine.events(on:tuesday).count == 13,"Workday must have 13 reminders")
check(routine.events(on:saturday).count == 10,"Weekend must have 10 reminders")
check(!routine.events(on:saturday).contains { $0.reminder.id.hasPrefix("focus") },"Weekend must have no work")
check(routine.events(on:saturday).last?.reminder.time == "23:00","Weekend sleep at 23:00")
check(routine.events(on:tuesday).last?.reminder.time == "23:30","Workday sleep at 23:30")
check(routine.events(on:tuesday).filter { $0.reminder.id.hasPrefix("walk") }.map { $0.reminder.time } == ["08:10","18:40"],"Workday dog walk times")
check(routine.events(on:saturday).filter { $0.reminder.id.hasPrefix("walk") }.map { $0.reminder.time } == ["09:10","19:40"],"Weekend dog walk times")
let dogTime = date("2026-09-15T00:10:05Z")
let due = routine.due(at:dogTime,delivered:[])
check(due.count == 1 && due[0].reminder.id == "walk-am","Due using Beijing timezone")
check(routine.due(at:dogTime,delivered:[due[0].key]).isEmpty,"Delivered reminders must not repeat")
check(routine.due(at:date("2026-09-15T00:11:30Z"),delivered:[]).isEmpty,"Do not replay expired reminders")
check(routine.next(after:date("2026-09-20T15:00:00Z"))?.date == date("2026-09-20T23:30:00Z"),"Sunday sleep to Monday wake")
check(routine.next(after:date("2026-09-18T15:30:00Z"))?.date == date("2026-09-19T00:30:00Z"),"Friday sleep to Saturday wake")
check(routine.events(on:date("2026-09-20T16:05:00Z")).first?.reminder.time == "07:30","UTC Sunday night is Beijing Monday")
check(routine.due(at:date("2026-09-20T16:00:00Z"),delivered:[]).isEmpty,"No midnight reminders")
print("PASS: weekday/weekend schedules, Beijing timezone, dog walks, midnight boundaries, due-time grace and deduplication")
