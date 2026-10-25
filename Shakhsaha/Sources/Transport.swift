import Network
import Foundation
import CoreBluetooth

protocol OBDTransport: AnyObject {
    var name: String { get }
    func open() async throws
    func send(_ command: String) async throws -> String
    func close()
}

enum OBDError: LocalizedError {
    case bluetoothOff, unauthorized, notFound, timeout, noCharacteristic, disconnected
    var errorDescription: String? {
        switch self {
        case .bluetoothOff: return L("البلوتوث مطفي، شغّله من مركز التحكم", "Bluetooth is off")
        case .unauthorized: return L("إذن البلوتوث مقفول، افتحه من الإعدادات", "Bluetooth permission denied")
        case .notFound: return L("ما لقينا قطعة OBD قريبة. تأكد إنها مركّبة والسويتش شغّال", "No OBD adapter found. Plug it in and turn ignition on")
        case .timeout: return L("القطعة ما ردّت، جرّب مرة ثانية", "Adapter did not respond")
        case .noCharacteristic: return L("القطعة هذي ما تدعم الاتصال (يمكن بلوتوث كلاسيك مو BLE)", "Adapter not supported (classic Bluetooth?)")
        case .disconnected: return L("انقطع الاتصال بالقطعة", "Adapter disconnected")
        }
    }
}

/// Scripted ELM327 emulator (same idea as qadanm/elmulator scenarios) used for demo mode and tests.
final class DemoTransport: OBDTransport {
    let name = "Demo ELM327 v1.5"
    var cleared = false
    var header = "7DF"
    var t: Double = 0
    var script: [String: String]
    init(script: [String: String]? = nil) {
        self.script = script ?? DemoTransport.defaultScript
    }
    static let defaultScript: [String: String] = [
        "ATZ": "ELM327 v1.5", "ATE0": "OK", "ATL0": "OK", "ATS0": "OK", "ATH0": "OK", "ATSP0": "OK", "ATRV": "12.4V",
        "0100": "4100BE3EB813", "0101": "41018307E100",
        "03": "430204200301", "07": "470101 71", "0A": "4A00",
        "0902": "014\r0:490201314E34\r1:414C33415032\r2:4332383933343536",
        "020200": "42020001 71",
    ]
    func open() async throws {}
    func close() {}
    /// Plausible hot-climate idle/cruise values for every standard PID in demo mode.
    static func demoValue(_ pid: String, t: Double = 0) -> String? {
        let w = sin(t / 4)
        switch pid {
        case "02": return "0171"
        case "04": return String(format: "%02X", Int(70 + 30 * w))
        case "05": return String(format: "%02X", 96 + 40)
        case "06": return String(format: "%02X", Int(130 + 4 * w))
        case "07": return "8A"
        case "08": return "7E"
        case "09": return "84"
        case "0B": return String(format: "%02X", Int(38 + 20 * w))
        case "0C": return "0F80"
        case "0D": return "3C"
        case "0E": return String(format: "%02X", Int(150 + 6 * w))
        case "0F": return String(format: "%02X", 52 + 40)
        case "10": let v = Int((6 + 5 * (0.5 + 0.5 * w)) * 100); return String(format: "%02X%02X", v / 256, v % 256)
        case "11": return String(format: "%02X", Int(40 + 25 * w))
        case "14": return String(format: "%02X00", Int(90 + 70 * sin(t * 3)))
        case "15": return "8CFF"
        case "1F": let v = Int(600 + t * 4); return String(format: "%02X%02X", (v / 256) % 256, v % 256)
        case "21": return "0000"
        case "2F": return "99"
        case "30": return "0C"
        case "31": return "0F3C"
        case "33": return "5E"
        case "3C": let v = (620 + 40) * 10; return String(format: "%02X%02X", v / 256, v % 256)
        case "42": return "3710"
        case "46": return String(format: "%02X", 44 + 40)
        case "5C": return String(format: "%02X", 104 + 40)
        case "5E": let v = Int((1.2 + 2 * (0.5 + 0.5 * w)) * 20); return String(format: "%02X%02X", v / 256, v % 256)
        default: return nil
        }
    }
    func send(_ command: String) async throws -> String {
        try await Task.sleep(nanoseconds: 60_000_000)
        let c = command.uppercased().replacingOccurrences(of: " ", with: "")
        if c.hasPrefix("ATSH") { header = String(c.dropFirst(4)); return "OK>" }
        if c == "ATD" { header = "7DF"; return "OK>" }
        if c.hasPrefix("19") {
            if cleared { return ["7E0", "7E1", "7B0"].contains(header) ? "5902FF>" : "NO DATA>" }
            switch header {
            case "7E0": return "5902FF04200009030100 09>"
            case "7E1": return "5902FF>"
            case "7B0": return "5902FF40350008>"
            case "780": return "5902FF>"
            default: return "NO DATA>"
            }
        }
        if c == "04" { cleared = true; return "44>" }
        if cleared && ["03", "07"].contains(c) { return c == "03" ? "4300>" : "4700>" }
        if cleared && c == "0101" { return "41010007E1E1>" }
        t += 0.25
        let rpm = 780 + 1700 * (0.5 + 0.5 * sin(t / 3)), spd = max(0, 60 * sin(t / 6)) // demo cruises
        switch c {
        case "010C": let v = Int(rpm * 4); return String(format: "410C%02X%02X>", v / 256, v % 256)
        case "010D": return String(format: "410D%02X>", Int(spd))
        case "0105": return String(format: "4105%02X>", Int(92 + 6 * sin(t / 10)) + 40)
        case "0111": return String(format: "4111%02X>", Int((14 + 20 * (0.5 + 0.5 * sin(t / 3))) * 2.55))
        case "0104": return String(format: "4104%02X>", Int((25 + 30 * (0.5 + 0.5 * sin(t / 3))) * 2.55))
        case "010F": return "410F4C>"
        case "012F": return "412F99>"
        case "0142": let v = Int((14.1 + 0.1 * sin(t)) * 1000); return String(format: "4142%02X%02X>", v / 256, v % 256)
        case "0106": return "410685>"
        case "0107": return "41078A>"
        case "0600": return "4600FFFF0000>"
        case "0601": return "4601 0B 24 00 7A 00 00 00 C8>"
        case "0621": return "4621 80 0D 01 F4 00 C8 03 E8>"
        case "06A2": return "46A2 0B 24 00 02 00 00 00 0A>"
        case "06A3": return "46A3 0B 24 00 0F 00 00 00 0A>"
        default:
            if c.count == 6, c.hasPrefix("02"), c.hasSuffix("00"), let r = DemoTransport.demoValue(String(c.dropFirst(2).prefix(2))) {
                let p2 = String(c.dropFirst(2).prefix(2)); return "42\(p2)00\(r)>"
            }
            if c.count == 4, c.hasPrefix("01"), let r = DemoTransport.demoValue(String(c.suffix(2)), t: t) {
                let p2 = String(c.suffix(2)); return "41\(p2)\(r)>"
            }
            return (script[c] ?? "NO DATA") + ">"
        }
    }
}

/// CoreBluetooth transport for BLE ELM327 adapters (Vgate iCar Pro BLE, vLinker MC-IOS, OBDLink CX/MX+, Veepeak BLE+).
final class BLETransport: NSObject, OBDTransport, CBCentralManagerDelegate, CBPeripheralDelegate {
    private(set) var name = "BLE"
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var notifyChar: CBCharacteristic?
    private var buffer = ""
    private var stateCont: CheckedContinuation<Void, Error>?
    private var openCont: CheckedContinuation<Void, Error>?
    private var replyCont: CheckedContinuation<String, Error>?
    private let q = DispatchQueue(label: "obd.ble")
    static let knownServices = ["FFF0", "FFE0", "18F0", "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2", "BEEF"].map { CBUUID(string: $0) }
    var discovered: [CBPeripheral] = []

    func open() async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            q.async { self.openCont = c; self.central = CBCentralManager(delegate: self, queue: self.q) }
            q.asyncAfter(deadline: .now() + 15) {
                if let oc = self.openCont { self.openCont = nil; self.central.stopScan(); oc.resume(throwing: OBDError.notFound) }
            }
        }
    }

    func close() {
        q.async { if let p = self.peripheral { self.central?.cancelPeripheralConnection(p) } }
    }

    func send(_ command: String) async throws -> String {
        guard let p = peripheral, let w = writeChar else { throw OBDError.disconnected }
        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<String, Error>) in
            q.async {
                self.buffer = ""
                self.replyCont = c
                let type: CBCharacteristicWriteType = w.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
                p.writeValue((command + "\r").data(using: .ascii)!, for: w, type: type)
                let cmd = command
                self.q.asyncAfter(deadline: .now() + ((cmd == "ATZ" || cmd == "0100") ? 8 : 4)) {
                    if let rc = self.replyCont { self.replyCont = nil; rc.resume(returning: self.buffer.isEmpty ? "NO DATA" : self.buffer) }
                }
            }
        }
    }

    // MARK: delegate
    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        switch c.state {
        case .poweredOn: c.scanForPeripherals(withServices: nil)
        case .poweredOff: fail(OBDError.bluetoothOff)
        case .unauthorized: fail(OBDError.unauthorized)
        default: break
        }
    }
    private func fail(_ e: Error) { if let oc = openCont { openCont = nil; oc.resume(throwing: e) } }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData ad: [String: Any], rssi: NSNumber) {
        let n = (p.name ?? (ad[CBAdvertisementDataLocalNameKey] as? String) ?? "").uppercased()
        let svcs = (ad[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let looksOBD = ["OBD", "ELM", "VLINK", "IOS-VLINK", "VEEPEAK", "ICAR", "V-LINK", "KONNWEI", "LELINK", "CX", "MX+", "VGATE"].contains { n.contains($0) }
            || svcs.contains { BLETransport.knownServices.contains($0) }
        guard looksOBD, peripheral == nil else { return }
        peripheral = p; name = p.name ?? "OBD"
        c.stopScan(); p.delegate = self; c.connect(p)
    }
    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) { p.discoverServices(nil) }
    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) { peripheral = nil; fail(OBDError.disconnected) }
    func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        writeChar = nil
        if let rc = replyCont { replyCont = nil; rc.resume(throwing: OBDError.disconnected) }
    }
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] { p.discoverCharacteristics(nil, for: s) }
    }
    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for ch in s.characteristics ?? [] {
            if notifyChar == nil, ch.properties.contains(.notify) || ch.properties.contains(.indicate) {
                notifyChar = ch; p.setNotifyValue(true, for: ch)
            }
            if writeChar == nil, ch.properties.contains(.write) || ch.properties.contains(.writeWithoutResponse) { writeChar = ch }
        }
        if writeChar != nil, notifyChar != nil, let oc = openCont { openCont = nil; oc.resume() }
    }
    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard let d = ch.value, let s = String(data: d, encoding: .ascii) else { return }
        buffer += s
        if buffer.contains(">"), let rc = replyCont { replyCont = nil; rc.resume(returning: buffer) }
    }
}



/// Wi-Fi ELM327 adapters (default 192.168.0.10:35000). Join the adapter's Wi-Fi network first.
final class WiFiTransport: OBDTransport {
    let name: String
    private let host: String, port: UInt16
    private var conn: NWConnection?
    private let q = DispatchQueue(label: "obd.wifi")
    init(host: String = "192.168.0.10", port: UInt16 = 35000) { self.host = host; self.port = port; name = "Wi-Fi \(host):\(port)" }

    func open() async throws {
        let c = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        conn = c
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            var done = false
            c.stateUpdateHandler = { st in
                guard !done else { return }
                switch st {
                case .ready: done = true; k.resume()
                case .failed, .cancelled: done = true; k.resume(throwing: OBDError.notFound)
                default: break
                }
            }
            c.start(queue: q)
            q.asyncAfter(deadline: .now() + 8) { if !done { done = true; c.cancel(); k.resume(throwing: OBDError.notFound) } }
        }
    }
    func close() { conn?.cancel(); conn = nil }

    func send(_ command: String) async throws -> String {
        guard let c = conn else { throw OBDError.disconnected }
        c.send(content: (command + "\r").data(using: .ascii), completion: .contentProcessed { _ in })
        var buf = ""
        let deadline = Date().addingTimeInterval(command == "ATZ" ? 6 : 4)
        while !buf.contains(">") && Date() < deadline {
            let chunk: String = try await withCheckedThrowingContinuation { k in
                c.receive(minimumIncompleteLength: 1, maximumLength: 1024) { d, _, _, err in
                    if let err { k.resume(throwing: err) } else { k.resume(returning: d.flatMap { String(data: $0, encoding: .ascii) } ?? "") }
                }
            }
            buf += chunk
        }
        return buf.isEmpty ? "NO DATA" : buf
    }
}
