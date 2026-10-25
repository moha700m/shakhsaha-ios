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
    func send(_ command: String) async throws -> String {
        try await Task.sleep(nanoseconds: 60_000_000)
        let c = command.uppercased().replacingOccurrences(of: " ", with: "")
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
        default: return (script[c] ?? "NO DATA") + ">"
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
