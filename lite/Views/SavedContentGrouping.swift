import Foundation

struct SavedContentGroup<Item: Identifiable>: Identifiable {
    let id: String
    let title: String
    let items: [Item]

    static func make(
        _ items: [Item], sortOrder: SavedSortOrder,
        date: (Item) -> Date, title: (Item) -> String,
        calendar: Calendar = .current, now: Date = .now
    ) -> [Self] {
        let sorted = items.sorted { lhs, rhs in
            let comparison = title(lhs).localizedStandardCompare(title(rhs))
            if sortOrder == .name, comparison != .orderedSame {
                return comparison == .orderedAscending
            }
            if date(lhs) != date(rhs) { return date(lhs) > date(rhs) }
            return comparison == .orderedAscending
        }
        guard !sorted.isEmpty else { return [] }
        if sortOrder == .name {
            return [Self(id: "name", title: "A–Z", items: sorted)]
        }

        // Calendar days, rather than 24-hour offsets, also work across daylight saving changes.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let buckets = Dictionary(grouping: sorted) { item in
            if calendar.isDate(date(item), inSameDayAs: now) { return "today" }
            if calendar.isDate(date(item), inSameDayAs: yesterday) { return "yesterday" }
            return "earlier"
        }
        return [("today", "Today"), ("yesterday", "Yesterday"), ("earlier", "Earlier")].compactMap { id, title in
            guard let entries = buckets[id] else { return nil }
            return Self(id: id, title: title, items: entries)
        }
    }
}
