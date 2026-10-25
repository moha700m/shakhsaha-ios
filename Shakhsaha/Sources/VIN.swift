import Foundation

enum VINDecoder {
    static let wmi: [String: String] = [
        "JT": "Toyota", "4T": "Toyota", "5T": "Toyota", "MR": "Toyota", "KM": "Hyundai", "5N": "Hyundai", "KN": "Kia", "5X": "Kia",
        "JN": "Nissan", "1N": "Nissan", "3N": "Nissan", "MD": "Nissan", "1F": "Ford", "3F": "Ford", "MA": "Mahindra", "MN": "Ford",
        "1G": "Chevrolet/GMC", "2G": "Chevrolet/GMC", "3G": "Chevrolet/GMC", "KL": "Chevrolet", "JH": "Honda", "1H": "Honda", "5J": "Honda",
        "JM": "Mazda", "JS": "Suzuki", "MM": "Mitsubishi", "JA": "Isuzu/Mitsubishi", "WB": "BMW", "WD": "Mercedes-Benz", "WV": "Volkswagen",
        "WA": "Audi", "LS": "Changan", "LV": "Geely/Changan", "LG": "Geely", "L6": "Geely", "LB": "MG/Geely", "LJ": "JAC", "SA": "Land Rover/Jaguar",
        "1C": "Chrysler/Jeep/Dodge", "2C": "Chrysler/Dodge", "1L": "Lincoln", "5Y": "Lexus/Toyota", "JTH": "Lexus", "JTJ": "Lexus",
    ]
    static func make(_ vin: String) -> String? {
        let v = vin.uppercased()
        if let m = wmi[String(v.prefix(3))] { return m }
        return wmi[String(v.prefix(2))]
    }
    static func year(_ vin: String) -> Int? {
        let v = Array(vin.uppercased()); guard v.count >= 10 else { return nil }
        let codes = Array("ABCDEFGHJKLMNPRSTVWXY123456789")
        guard let i = codes.firstIndex(of: v[9]) else { return nil }
        var y = 2010 + i
        if y > Calendar.current.component(.year, from: Date()) + 1 { y -= 30 }
        return y
    }
    static func isValid(_ vin: String) -> Bool {
        vin.count == 17 && !vin.uppercased().contains(where: { "IOQ".contains($0) })
    }
}
