import Foundation

struct MaintItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: String           // oil, battery, ac, tires, filter, istimara, mvpi, insurance, custom
    var title: String
    var due: Date
    var everyMonths: Int
    var done = false
}

@MainActor
final class MaintenanceStore: ObservableObject {
    @Published var items: [MaintItem] = [] { didSet { save() } }
    private let key = "shakhsaha.maint"
    init() {
        if let d = UserDefaults.standard.data(forKey: key), let v = try? JSONDecoder().decode([MaintItem].self, from: d) { items = v }
        else { items = Self.defaults() }
    }
    static func defaults() -> [MaintItem] {
        let cal = Calendar.current, now = Date()
        func m(_ n: Int) -> Date { cal.date(byAdding: .month, value: n, to: now) ?? now }
        return [
            MaintItem(kind: "oil", title: L("تغيير الزيت والفلتر", "Oil & filter change"), due: m(3), everyMonths: 6),
            MaintItem(kind: "battery", title: L("فحص البطارية (قبل الصيف)", "Battery check (before summer)"), due: m(2), everyMonths: 6),
            MaintItem(kind: "ac", title: L("فحص المكيف والفريون", "A/C & refrigerant check"), due: m(4), everyMonths: 12),
            MaintItem(kind: "filter", title: L("فلتر الهوا بعد الغبار", "Air filter after dust"), due: m(2), everyMonths: 4),
            MaintItem(kind: "tires", title: L("الكفرات وتاريخ صنعها", "Tires & manufacture date"), due: m(6), everyMonths: 6),
            MaintItem(kind: "mvpi", title: L("الفحص الدوري", "Periodic inspection (MVPI)"), due: m(10), everyMonths: 12),
        ]
    }
    func add(_ i: MaintItem) { items.append(i); schedule(i) }
    func markDone(_ i: MaintItem) {
        guard let idx = items.firstIndex(of: i) else { return }
        var n = items[idx]
        n.due = Calendar.current.date(byAdding: .month, value: max(1, n.everyMonths), to: Date()) ?? Date()
        items[idx] = n; schedule(n)
    }
    func remove(_ i: MaintItem) { items.removeAll { $0.id == i.id }; Notifier.cancel(i.id.uuidString) }
    func scheduleAll() { items.forEach(schedule) }
    private func schedule(_ i: MaintItem) {
        var d = Calendar.current.date(byAdding: .day, value: -3, to: i.due) ?? i.due
        d = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: d) ?? d
        guard d > Date() else { return }
        Notifier.schedule(id: i.id.uuidString, title: L("تذكير صيانة", "Maintenance reminder"), body: i.title, at: d)
    }
    private func save() { if let d = try? JSONEncoder().encode(items) { UserDefaults.standard.set(d, forKey: key) } }
}
