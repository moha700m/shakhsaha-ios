import Foundation

struct Vehicle: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var make: String = ""
    var model: String = ""
    var year: Int = 2020
    var vin: String = ""
    var odometer: Int = 0
    var fuel: String = "91"
    var city: String = "riyadh"
    var notes: String = ""
}

@MainActor
final class VehicleStore: ObservableObject {
    @Published var cars: [Vehicle] = [] { didSet { save() } }
    @Published var currentId: UUID? { didSet { UserDefaults.standard.set(currentId?.uuidString, forKey: key + ".cur") } }
    private let key = "shakhsaha.cars"
    init() {
        if let d = UserDefaults.standard.data(forKey: key), let v = try? JSONDecoder().decode([Vehicle].self, from: d) { cars = v }
        if cars.isEmpty { cars = [Vehicle(name: L("سيارتي", "My car"))] }
        currentId = UserDefaults.standard.string(forKey: key + ".cur").flatMap(UUID.init) ?? cars.first?.id
    }
    var current: Vehicle {
        get { cars.first { $0.id == currentId } ?? cars[0] }
        set { if let i = cars.firstIndex(where: { $0.id == newValue.id }) { cars[i] = newValue } }
    }
    func add(_ v: Vehicle) { cars.append(v); currentId = v.id }
    func remove(_ v: Vehicle) { guard cars.count > 1 else { return }; cars.removeAll { $0.id == v.id }; if currentId == v.id { currentId = cars.first?.id } }
    private func save() { if let d = try? JSONEncoder().encode(cars) { UserDefaults.standard.set(d, forKey: key) } }
}
