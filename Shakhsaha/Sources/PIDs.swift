import Foundation

/// Standard SAE J1979 Mode 01 PIDs with decoders. Used by the custom dashboard, sensors list, recorder and freeze frame.
struct PIDDef: Identifiable, Hashable {
    let id: String
    let pid: UInt8
    let ar: String
    let en: String
    let unit: String
    let min: Double
    let max: Double
    let warn: Double?      // red above
    let low: Double?       // red below
    let fmt: String
    let f: ([UInt8]) -> Double?
    var name: String { L(ar, en) }
    var command: String { String(format: "01%02X", pid) }
    static func == (a: PIDDef, b: PIDDef) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
    func decode(_ d: [UInt8]) -> Double? { f(d) }
}

enum PIDs {
    private static func A(_ d: [UInt8]) -> Double? { d.count > 0 ? Double(d[0]) : nil }
    private static func AB(_ d: [UInt8]) -> Double? { d.count > 1 ? Double(d[0]) * 256 + Double(d[1]) : nil }
    static let all: [PIDDef] = [
        PIDDef(id: "rpm", pid: 0x0C, ar: "الدورات", en: "RPM", unit: "rpm", min: 0, max: 7000, warn: 6000, low: nil, fmt: "%.0f") { AB($0).map { $0 / 4 } },
        PIDDef(id: "speed", pid: 0x0D, ar: "السرعة", en: "Speed", unit: "km/h", min: 0, max: 220, warn: nil, low: nil, fmt: "%.0f") { A($0) },
        PIDDef(id: "coolant", pid: 0x05, ar: "حرارة الماء", en: "Coolant", unit: "°C", min: -40, max: 130, warn: 105, low: nil, fmt: "%.0f") { A($0).map { $0 - 40 } },
        PIDDef(id: "voltage", pid: 0x42, ar: "فولت الكمبيوتر", en: "Module voltage", unit: "V", min: 10, max: 16, warn: 15.2, low: 12.2, fmt: "%.1f") { AB($0).map { $0 / 1000 } },
        PIDDef(id: "throttle", pid: 0x11, ar: "بوابة الهواء", en: "Throttle", unit: "%", min: 0, max: 100, warn: nil, low: nil, fmt: "%.0f") { A($0).map { $0 * 100 / 255 } },
        PIDDef(id: "load", pid: 0x04, ar: "حمل المحرك", en: "Engine load", unit: "%", min: 0, max: 100, warn: 92, low: nil, fmt: "%.0f") { A($0).map { $0 * 100 / 255 } },
        PIDDef(id: "intake", pid: 0x0F, ar: "حرارة الهواء الداخل", en: "Intake air temp", unit: "°C", min: -40, max: 90, warn: 70, low: nil, fmt: "%.0f") { A($0).map { $0 - 40 } },
        PIDDef(id: "ambient", pid: 0x46, ar: "حرارة الجو", en: "Ambient temp", unit: "°C", min: -10, max: 60, warn: 48, low: nil, fmt: "%.0f") { A($0).map { $0 - 40 } },
        PIDDef(id: "oil", pid: 0x5C, ar: "حرارة الزيت", en: "Oil temp", unit: "°C", min: -40, max: 160, warn: 130, low: nil, fmt: "%.0f") { A($0).map { $0 - 40 } },
        PIDDef(id: "maf", pid: 0x10, ar: "تدفق الهواء MAF", en: "MAF", unit: "g/s", min: 0, max: 250, warn: nil, low: nil, fmt: "%.1f") { AB($0).map { $0 / 100 } },
        PIDDef(id: "map", pid: 0x0B, ar: "ضغط المنفولد", en: "Intake manifold", unit: "kPa", min: 0, max: 255, warn: nil, low: nil, fmt: "%.0f") { A($0) },
        PIDDef(id: "baro", pid: 0x33, ar: "الضغط الجوي", en: "Barometric", unit: "kPa", min: 60, max: 110, warn: nil, low: nil, fmt: "%.0f") { A($0) },
        PIDDef(id: "timing", pid: 0x0E, ar: "توقيت الشرارة", en: "Timing advance", unit: "°", min: -64, max: 64, warn: nil, low: nil, fmt: "%.1f") { A($0).map { $0 / 2 - 64 } },
        PIDDef(id: "stft1", pid: 0x06, ar: "تعديل الوقود القصير ب1", en: "Short fuel trim B1", unit: "%", min: -25, max: 25, warn: 15, low: -15, fmt: "%.1f") { A($0).map { $0 * 100 / 128 - 100 } },
        PIDDef(id: "ltft1", pid: 0x07, ar: "تعديل الوقود الطويل ب1", en: "Long fuel trim B1", unit: "%", min: -25, max: 25, warn: 10, low: -10, fmt: "%.1f") { A($0).map { $0 * 100 / 128 - 100 } },
        PIDDef(id: "stft2", pid: 0x08, ar: "تعديل الوقود القصير ب2", en: "Short fuel trim B2", unit: "%", min: -25, max: 25, warn: 15, low: -15, fmt: "%.1f") { A($0).map { $0 * 100 / 128 - 100 } },
        PIDDef(id: "ltft2", pid: 0x09, ar: "تعديل الوقود الطويل ب2", en: "Long fuel trim B2", unit: "%", min: -25, max: 25, warn: 10, low: -10, fmt: "%.1f") { A($0).map { $0 * 100 / 128 - 100 } },
        PIDDef(id: "o2s1", pid: 0x14, ar: "حساس أكسجين ب1 ح1", en: "O2 B1S1", unit: "V", min: 0, max: 1.275, warn: nil, low: nil, fmt: "%.2f") { A($0).map { $0 / 200 } },
        PIDDef(id: "o2s2", pid: 0x15, ar: "حساس أكسجين ب1 ح2", en: "O2 B1S2", unit: "V", min: 0, max: 1.275, warn: nil, low: nil, fmt: "%.2f") { A($0).map { $0 / 200 } },
        PIDDef(id: "fuel", pid: 0x2F, ar: "مستوى البنزين", en: "Fuel level", unit: "%", min: 0, max: 100, warn: nil, low: 12, fmt: "%.0f") { A($0).map { $0 * 100 / 255 } },
        PIDDef(id: "fuelrate", pid: 0x5E, ar: "استهلاك البنزين", en: "Fuel rate", unit: "L/h", min: 0, max: 40, warn: nil, low: nil, fmt: "%.1f") { AB($0).map { $0 / 20 } },
        PIDDef(id: "catTemp", pid: 0x3C, ar: "حرارة دبة التلوث", en: "Catalyst temp", unit: "°C", min: 0, max: 1000, warn: 900, low: nil, fmt: "%.0f") { AB($0).map { $0 / 10 - 40 } },
        PIDDef(id: "runtime", pid: 0x1F, ar: "مدة التشغيل", en: "Run time", unit: "s", min: 0, max: 65535, warn: nil, low: nil, fmt: "%.0f") { AB($0) },
        PIDDef(id: "milDist", pid: 0x21, ar: "مسافة واللمبة شغّالة", en: "Distance with MIL", unit: "km", min: 0, max: 65535, warn: nil, low: nil, fmt: "%.0f") { AB($0) },
        PIDDef(id: "clrDist", pid: 0x31, ar: "مسافة من آخر مسح", en: "Distance since clear", unit: "km", min: 0, max: 65535, warn: nil, low: nil, fmt: "%.0f") { AB($0) },
        PIDDef(id: "warmups", pid: 0x30, ar: "تسخينات من آخر مسح", en: "Warm-ups since clear", unit: "", min: 0, max: 255, warn: nil, low: nil, fmt: "%.0f") { A($0) },
    ]
    static let byId: [String: PIDDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static func def(_ id: String) -> PIDDef? { byId[id] }
}

struct Mode06Result: Identifiable, Hashable {
    var id: String { String(format: "%02X-%02X", mid, tid) }
    let mid: UInt8, tid: UInt8, uas: UInt8
    let value: Int, min: Int, max: Int
    var pass: Bool { value >= min && value <= max }
    var monitorName: String {
        switch mid {
        case 0x01...0x10: return L("حساس أكسجين \(mid)", "O2 sensor \(mid)")
        case 0x21...0x24: return L("دبة التلوث بنك \(mid - 0x20)", "Catalyst bank \(mid - 0x20)")
        case 0x31...0x3D: return L("نظام EGR / VVT", "EGR / VVT")
        case 0x39...0x3F: return L("أبخرة البنزين EVAP", "EVAP")
        case 0x41...0x50: return L("سخان حساس الأكسجين", "O2 heater")
        case 0xA1: return L("تفويت عام", "Misfire general")
        case 0xA2...0xAD: return L("تفويت سلندر \(mid - 0xA1)", "Misfire cylinder \(mid - 0xA1)")
        default: return String(format: "MID %02X", mid)
        }
    }
}

extension ELMParser {
    /// Mode 06 CAN format: 46 MID TID UASID VAL(2) MIN(2) MAX(2), possibly repeated.
    static func mode06(_ raw: String) -> [Mode06Result] {
        if isError(raw) { return [] }
        let b = bytes(raw)
        guard let i0 = b.firstIndex(of: 0x46) else { return [] }
        var out: [Mode06Result] = []
        var i = i0 + 1
        let mid = i < b.count ? b[i] : 0
        i += 1
        while i + 7 < b.count {
            let tid = b[i], uas = b[i + 1]
            let v = Int(b[i + 2]) << 8 | Int(b[i + 3]), mn = Int(b[i + 4]) << 8 | Int(b[i + 5]), mx = Int(b[i + 6]) << 8 | Int(b[i + 7])
            out.append(Mode06Result(mid: mid, tid: tid, uas: uas, value: v, min: mn, max: mx))
            i += 8
            if i < b.count && b[i] == mid { i += 1 }   // repeated MID before next test
        }
        return out
    }

    /// Supported-PID bitmask from 0100/0120/0140/... replies.
    static func supported(_ raw: String, base: UInt8) -> Set<UInt8> {
        guard let d = pidData(raw, pid: base), d.count >= 4 else { return [] }
        var s = Set<UInt8>()
        for (byteIdx, byte) in d.prefix(4).enumerated() {
            for bit in 0..<8 where byte & (0x80 >> bit) != 0 { s.insert(base + UInt8(byteIdx * 8 + bit + 1)) }
        }
        return s
    }
}
