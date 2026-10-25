import Foundation

/// Pure, testable parsing of ELM327 responses. Read-only OBD-II (modes 01, 02, 03, 04*, 07, 09, 0A).
/// *Mode 04 (clear codes) is the only command that changes ECU state, and only clears stored fault memory.
enum ELMParser {
    /// Normalises a raw ELM reply: strips prompt, echo, spaces, "SEARCHING...", line feeds.
    static func clean(_ raw: String) -> [String] {
        raw.replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.uppercased().hasPrefix("SEARCHING") && $0.uppercased() != "OK" }
    }

    static func isError(_ raw: String) -> Bool {
        let u = raw.uppercased()
        return ["NO DATA", "UNABLE TO CONNECT", "CAN ERROR", "BUS INIT", "STOPPED", "ERROR", "?"].contains { u.contains($0) }
    }

    /// Hex bytes from all lines, dropping CAN frame headers like "0:" "1:" and a leading byte count line.
    static func bytes(_ raw: String) -> [UInt8] {
        var out: [UInt8] = []
        let lines = clean(raw)
        for var line in lines {
            if let r = line.range(of: ":") { line = String(line[r.upperBound...]) }
            let hex = line.replacingOccurrences(of: " ", with: "")
            // skip pure byte-count lines like "013" in multi-frame
            if lines.count > 1 && hex.count <= 3 && !line.contains(" ") { continue }
            var i = hex.startIndex
            while let j = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex), i < hex.endIndex {
                if let b = UInt8(hex[i..<j], radix: 16) { out.append(b) }
                i = j
            }
        }
        return out
    }

    /// Mode 01 / 02 data bytes after the response header (41 xx / 42 xx [frame]).
    static func pidData(_ raw: String, mode: UInt8 = 0x41, pid: UInt8) -> [UInt8]? {
        let b = bytes(raw)
        guard let idx = b.indices.first(where: { $0 + 1 < b.count && b[$0] == mode && b[$0 + 1] == pid }) else { return nil }
        let start = idx + (mode == 0x42 ? 3 : 2)
        guard start <= b.count else { return nil }
        return Array(b[start...])
    }

    /// Decodes DTCs from mode 03 (0x43), 07 (0x47), 0A (0x4A) replies.
    static func dtcs(_ raw: String, response: UInt8) -> [String] {
        if isError(raw) { return [] }
        var b = bytes(raw)
        guard let idx = b.firstIndex(of: response) else { return [] }
        b = Array(b[(idx + 1)...])
        // CAN replies carry a count byte; legacy replies don't. If odd length, drop count.
        if b.count % 2 == 1 { b.removeFirst() }
        var codes: [String] = []
        var i = 0
        while i + 1 < b.count {
            let a = b[i], c = b[i + 1]; i += 2
            if a == 0 && c == 0 { continue }
            if a == response { continue }
            codes.append(dtcString(a, c))
        }
        return Array(NSOrderedSet(array: codes)) as? [String] ?? codes
    }

    static func dtcString(_ a: UInt8, _ b: UInt8) -> String {
        let sys = ["P", "C", "B", "U"][Int(a >> 6)]
        let d1 = (a >> 4) & 0x3
        return String(format: "%@%d%X%02X", sys, d1, a & 0x0F, b)
    }

    /// VIN from mode 09 02.
    static func vin(_ raw: String) -> String? {
        let b = bytes(raw)
        guard let idx = b.firstIndex(of: 0x49), idx + 1 < b.count, b[idx + 1] == 0x02 else { return nil }
        let chars = b[(idx + 2)...].filter { $0 >= 0x30 && $0 <= 0x5A }
        let s = String(bytes: chars, encoding: .ascii) ?? ""
        return s.count >= 17 ? String(s.suffix(17)) : (s.isEmpty ? nil : s)
    }

    struct Readiness: Equatable {
        var milOn: Bool
        var dtcCount: Int
        var monitors: [(id: String, complete: Bool)]
        static func == (l: Readiness, r: Readiness) -> Bool {
            l.milOn == r.milOn && l.dtcCount == r.dtcCount && l.monitors.map { "\($0.id)\($0.complete)" } == r.monitors.map { "\($0.id)\($0.complete)" }
        }
        var incomplete: Int { monitors.filter { !$0.complete }.count }
    }

    /// Mode 01 PID 01 monitor status since DTCs cleared.
    static func readiness(_ raw: String) -> Readiness? {
        guard let d = pidData(raw, pid: 0x01), d.count >= 4 else { return nil }
        let A = d[0], B = d[1], C = d[2], D = d[3]
        var m: [(String, Bool)] = []
        // continuous monitors: B bits 0..2 supported, 4..6 incomplete
        let cont = [("misfire", 0), ("fuel", 1), ("components", 2)]
        for (n, bit) in cont where B & (1 << bit) != 0 { m.append((n, B & (1 << (bit + 4)) == 0)) }
        let diesel = B & 0x08 != 0
        let names = diesel ? ["nmhc", "nox", "", "boost", "", "egs", "pm", "egr"]
                           : ["catalyst", "heatedCat", "evap", "secondaryAir", "acRefrigerant", "o2", "o2Heater", "egr"]
        for bit in 0..<8 where C & (1 << bit) != 0 && !names[bit].isEmpty {
            m.append((names[bit], D & (1 << bit) == 0))
        }
        return Readiness(milOn: A & 0x80 != 0, dtcCount: Int(A & 0x7F), monitors: m)
    }

    enum PID: UInt8, CaseIterable {
        case load = 0x04, coolant = 0x05, rpm = 0x0C, speed = 0x0D, intake = 0x0F, throttle = 0x11, voltage = 0x42, fuelLevel = 0x2F, stft = 0x06, ltft = 0x07
    }

    static func decode(_ pid: PID, _ d: [UInt8]) -> Double? {
        func a() -> Double? { d.count > 0 ? Double(d[0]) : nil }
        func ab() -> Double? { d.count > 1 ? Double(d[0]) * 256 + Double(d[1]) : nil }
        switch pid {
        case .load, .throttle, .fuelLevel: return a().map { $0 * 100 / 255 }
        case .coolant, .intake: return a().map { $0 - 40 }
        case .rpm: return ab().map { $0 / 4 }
        case .speed: return a()
        case .voltage: return ab().map { $0 / 1000 }
        case .stft, .ltft: return a().map { $0 * 100 / 128 - 100 }
        }
    }

    /// ATRV battery voltage reply like "12.6V".
    static func atrv(_ raw: String) -> Double? {
        let s = clean(raw).joined().uppercased().replacingOccurrences(of: "V", with: "")
        return Double(s)
    }
}
