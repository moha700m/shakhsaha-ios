import AudioToolbox
import UIKit
import Foundation
import SwiftUI
import UserNotifications

enum ConnState: Equatable { case idle, connecting, connected(String), failed(String) }

struct FoundCode: Identifiable, Hashable {
    enum Kind: String { case stored, pending, permanent }
    var id: String { code + kind.rawValue }
    let code: String
    let kind: Kind
    var info: DTCInfo { DTCDatabase.info(code) }
    var kindTitle: String {
        switch kind {
        case .stored: return L("مخزّن", "Stored")
        case .pending: return L("معلّق", "Pending")
        case .permanent: return L("دائم", "Permanent")
        }
    }
}

struct LiveData: Equatable {
    var rpm: Double = 0, speed: Double = 0, coolant: Double = 0, voltage: Double = 0, throttle: Double = 0, load: Double = 0, intake: Double = 0, fuel: Double = 0
}

struct ScanResult: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var vin: String?
    var codes: [String: String]     // code -> kind
    var score: Int
    var milOn: Bool
    var monitorsIncomplete: Int
    var monitorsTotal: Int
    var voltage: Double?
}

struct Sample: Identifiable, Codable {
    var id: Double { t }
    let t: Double
    let v: [String: Double]
}

enum ConnKind: String, CaseIterable, Identifiable { case ble, wifi, demo; var id: String { rawValue } }

@MainActor
final class OBDService: ObservableObject {
    @Published var state: ConnState = .idle
    @Published var isDemo = false
    @Published var codes: [FoundCode] = []
    @Published var readiness: ELMParser.Readiness?
    @Published var vin: String?
    @Published var freezeFrameCode: String?
    @Published var freezeValues: [String: Double] = [:]
    @Published var live = LiveData()
    @Published var values: [String: Double] = [:]
    @Published var supported: Set<UInt8> = []
    @Published var mode06: [Mode06Result] = []
    @Published var scanning = false
    @Published var scanProgress: Double = 0
    @Published var lastScan: ScanResult?
    @Published var history: [ScanResult] = []
    @Published var heatAlert = false
    @Published var passengerMode = false
    @Published var hudActive = false
    @Published var recording = false
    @Published var samples: [Sample] = []
    @Published var dashboard: [String] = (UserDefaults.standard.stringArray(forKey: "shakhsaha.dash") ?? ["rpm", "speed", "coolant", "voltage", "throttle", "load"]) {
        didSet { UserDefaults.standard.set(dashboard, forKey: "shakhsaha.dash") }
    }
    @Published var soundAlerts = UserDefaults.standard.object(forKey: "shakhsaha.sound") as? Bool ?? true {
        didSet { UserDefaults.standard.set(soundAlerts, forKey: "shakhsaha.sound") }
    }
    // trip computer
    @Published var tripKm: Double = 0
    @Published var tripFuelL: Double = 0
    @Published var tripStart: Date?
    // acceleration
    @Published var accelArmed = false
    @Published var accelStart: Date?
    @Published var accelResult: Double?
    @Published var accelBest: Double? = UserDefaults.standard.object(forKey: "shakhsaha.best0100") as? Double

    @Published var modules: [ModuleResult] = []
    @Published var moduleScanning = false
    @Published var scoreHistory: [ScanResult] = []

    var heatLimit: Double = 105
    var wifiHost = "192.168.0.10"
    private var transport: OBDTransport?
    private var liveTask: Task<Void, Never>?
    private var lastTick = Date()
    private var t0 = Date()
    private var alerted: Set<String> = []
    private let histKey = "shakhsaha.history"

    init() {
        if let d = UserDefaults.standard.data(forKey: histKey), let h = try? JSONDecoder().decode([ScanResult].self, from: d) {
            history = h; lastScan = h.first
        }
    }

    var connected: Bool { if case .connected = state { return true }; return false }
    var drivingLocked: Bool { live.speed > 10 && !passengerMode && !hudActive && !isDemo }

    func connect(demo: Bool) async { await connect(kind: demo ? .demo : .ble) }

    func connect(kind: ConnKind) async {
        state = .connecting
        isDemo = kind == .demo
        let t: OBDTransport
        switch kind {
        case .demo: t = DemoTransport()
        case .ble: t = BLETransport()
        case .wifi: t = WiFiTransport(host: wifiHost)
        }
        do {
            try await t.open()
            for c in ["ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0"] { _ = try await t.send(c) }
            let probe = try await t.send("0100")
            if ELMParser.isError(probe) && kind != .demo { throw OBDError.timeout }
            var sup = ELMParser.supported(probe, base: 0x00)
            for base: UInt8 in [0x20, 0x40] where sup.contains(base) {
                if let r = try? await t.send(String(format: "01%02X", base)) { sup.formUnion(ELMParser.supported(r, base: base)) }
            }
            if kind == .demo { sup = Set(PIDs.all.map { $0.pid }) }
            supported = sup
            transport = t
            state = .connected(t.name)
        } catch {
            t.close()
            state = .failed(error.localizedDescription)
        }
    }

    func disconnect() {
        stopLive(); transport?.close(); transport = nil; state = .idle; isDemo = false
    }

    func isSupported(_ d: PIDDef) -> Bool { supported.isEmpty || supported.contains(d.pid) }

    func fullScan(catalog: RemoteCatalog) async {
        guard let t = transport else { return }
        scanning = true; scanProgress = 0
        defer { scanning = false }
        var found: [FoundCode] = []
        let steps: [(String, UInt8, FoundCode.Kind)] = [("03", 0x43, .stored), ("07", 0x47, .pending), ("0A", 0x4A, .permanent)]
        for (i, s) in steps.enumerated() {
            if let r = try? await t.send(s.0) {
                for c in ELMParser.dtcs(r, response: s.1) where !found.contains(where: { $0.code == c }) { found.append(FoundCode(code: c, kind: s.2)) }
            }
            scanProgress = Double(i + 1) / 8
        }
        codes = found
        if let r = try? await t.send("0101") { readiness = ELMParser.readiness(r) }
        scanProgress = 4 / 8
        if let r = try? await t.send("0902") { vin = ELMParser.vin(r) }
        scanProgress = 5 / 8
        await readFreezeFrame()
        scanProgress = 6 / 8
        if let r = try? await t.send("0142"), let d = ELMParser.pidData(r, pid: 0x42) { live.voltage = ELMParser.decode(.voltage, d) ?? live.voltage }
        else if let r = try? await t.send("ATRV"), let v = ELMParser.atrv(r) { live.voltage = v }
        scanProgress = 1
        let score = HealthScore.compute(codes: found, readiness: readiness, voltage: live.voltage)
        let res = ScanResult(vin: vin, codes: Dictionary(found.map { ($0.code, $0.kind.rawValue) }, uniquingKeysWith: { a, _ in a }),
                             score: score, milOn: readiness?.milOn ?? false, monitorsIncomplete: readiness?.incomplete ?? 0,
                             monitorsTotal: readiness?.monitors.count ?? 0, voltage: live.voltage > 0 ? live.voltage : nil)
        lastScan = res
        history.insert(res, at: 0); history = Array(history.prefix(30))
        if let d = try? JSONEncoder().encode(history) { UserDefaults.standard.set(d, forKey: histKey) }
    }

    /// Mode 02 frame 0: sensor snapshot when the fault was stored.
    func readFreezeFrame() async {
        guard let t = transport else { return }
        freezeValues = [:]
        if let r = try? await t.send("020200"), let d = ELMParser.pidData(r, mode: 0x42, pid: 0x02), d.count >= 2, d[0] | d[1] != 0 {
            freezeFrameCode = ELMParser.dtcString(d[0], d[1])
        } else { freezeFrameCode = nil; return }
        for id in ["rpm", "speed", "coolant", "load", "throttle", "intake", "stft1", "ltft1", "map"] {
            guard let def = PIDs.def(id) else { continue }
            if let r = try? await t.send(String(format: "02%02X00", def.pid)), let d = ELMParser.pidData(r, mode: 0x42, pid: def.pid), let v = def.decode(d) {
                freezeValues[id] = v
            }
        }
    }

    /// Full-system scan: each module is addressed physically and asked for DTCs via UDS 0x19 02 (read-only).
    func fullSystemScan() async {
        guard let t = transport else { return }
        moduleScanning = true
        modules = Modules.all.map { ModuleResult(module: $0, status: .pending, codes: []) }
        for i in modules.indices {
            modules[i].status = .scanning
            _ = try? await t.send("ATSH" + modules[i].module.header)
            var r = (try? await t.send("1902FF")) ?? "NO DATA"
            if ELMParser.isError(r) { r = (try? await t.send("190208")) ?? "NO DATA" }
            if let codes = Modules.parseUDS(r) {
                modules[i].codes = codes; modules[i].status = .ok(codes.count)
            } else if modules[i].module.id == "engine" {
                modules[i].codes = codes.map { $0.code }; modules[i].status = .generic   // fall back to generic OBD result
            } else {
                modules[i].status = .noResponse
            }
        }
        _ = try? await t.send("ATSH7DF")
        moduleScanning = false
    }

    /// Mode 06 on-board monitor test results (read-only).
    func readMode06() async {
        guard let t = transport else { return }
        var out: [Mode06Result] = []
        let mids: [UInt8] = [0x01, 0x02, 0x05, 0x06, 0x21, 0x22, 0x31, 0x35, 0x39, 0x3B, 0x41, 0x42, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6]
        for m in mids {
            if let r = try? await t.send(String(format: "06%02X", m)) { out += ELMParser.mode06(r) }
        }
        mode06 = out
    }

    /// Mode 04: clears stored fault memory only. No other writes/coding are ever sent.
    func clearCodes(catalog: RemoteCatalog) async {
        guard let t = transport else { return }
        _ = try? await t.send("04")
        await fullScan(catalog: catalog)
    }

    func startLive() {
        guard let t = transport, liveTask == nil else { return }
        lastTick = Date()
        liveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                var ids = Set(self.dashboard).union(["speed", "rpm", "coolant", "maf", "fuelrate", "voltage"])
                if self.supported.isEmpty == false { ids = ids.filter { PIDs.def($0).map(self.isSupported) ?? false } }
                for id in ids.sorted() {
                    guard !Task.isCancelled, let def = PIDs.def(id) else { continue }
                    guard let r = try? await t.send(def.command), let d = ELMParser.pidData(r, pid: def.pid), let v = def.decode(d) else { continue }
                    self.apply(id, v)
                }
                self.tick()
            }
        }
    }

    func stopLive() { liveTask?.cancel(); liveTask = nil }

    func startRecording() { samples = []; t0 = Date(); recording = true }
    func stopRecording() { recording = false }

    func resetTrip() { tripKm = 0; tripFuelL = 0; tripStart = Date() }

    func armAccel() { accelArmed = true; accelStart = nil; accelResult = nil }

    /// Fuel L/h: PID 5E if available, otherwise MAF / (AFR 14.7 * 740 g/L) * 3600.
    var fuelRateLh: Double {
        if let r = values["fuelrate"], r > 0 { return r }
        if let m = values["maf"] { return m * 3600 / (14.7 * 740) }
        return 0
    }
    var instantL100: Double? { live.speed > 3 ? fuelRateLh / live.speed * 100 : nil }
    var avgL100: Double? { tripKm > 0.2 ? tripFuelL / tripKm * 100 : nil }

    private func tick() {
        let now = Date(), dt = now.timeIntervalSince(lastTick); lastTick = now
        guard dt > 0, dt < 5 else { return }
        if tripStart == nil { tripStart = now }
        tripKm += live.speed * dt / 3600
        tripFuelL += fuelRateLh * dt / 3600
        if recording {
            samples.append(Sample(t: now.timeIntervalSince(t0), v: values))
            if samples.count > 3600 { samples.removeFirst() }
        }
        // 0-100 timer
        if accelArmed {
            if accelStart == nil && live.speed > 0.5 { accelStart = now }
            if let s = accelStart, live.speed >= 100 {
                let r = now.timeIntervalSince(s); accelResult = r; accelArmed = false
                if accelBest == nil || r < accelBest! { accelBest = r; UserDefaults.standard.set(r, forKey: "shakhsaha.best0100") }
                Haptics.success()
            }
        }
    }

    private func apply(_ id: String, _ v: Double) {
        values[id] = v
        switch id {
        case "rpm": live.rpm = v
        case "speed": live.speed = v
        case "coolant":
            live.coolant = v
            if v >= heatLimit && !heatAlert { heatAlert = true; Notifier.heat(v) }
            if v < heatLimit - 5 { heatAlert = false }
        case "throttle": live.throttle = v
        case "voltage": live.voltage = v
        case "load": live.load = v
        case "intake": live.intake = v
        case "fuel": live.fuel = v
        default: break
        }
        if let d = PIDs.def(id) {
            let bad = (d.warn.map { v >= $0 } ?? false) || (d.low.map { v > 0 && v < $0 } ?? false)
            if bad && !alerted.contains(id) { alerted.insert(id); if soundAlerts { Haptics.alarm() } }
            if !bad { alerted.remove(id) }
        }
    }

    func csv() -> URL {
        let keys = Array(Set(samples.flatMap { $0.v.keys })).sorted()
        var s = "t_s," + keys.map { k in "\(k)_\(PIDs.def(k)?.unit ?? "")" }.joined(separator: ",") + "\n"
        for x in samples { s += String(format: "%.2f", x.t) + "," + keys.map { x.v[$0].map { String(format: "%.3f", $0) } ?? "" }.joined(separator: ",") + "\n" }
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("shakhsaha-log-\(Int(Date().timeIntervalSince1970)).csv")
        try? s.data(using: .utf8)?.write(to: u)
        return u
    }

    /// Clearly-labelled sample recording for offline graphs.
    func loadDemoSamples() {
        var out: [Sample] = []
        for i in 0..<240 {
            let t = Double(i) * 0.5, w = sin(t / 6)
            out.append(Sample(t: t, v: ["rpm": 900 + 1800 * (0.5 + 0.5 * w), "speed": max(0, 70 * sin(t / 25)), "coolant": 90 + 8 * sin(t / 40),
                                         "voltage": 14.1 + 0.15 * sin(t), "throttle": 15 + 30 * (0.5 + 0.5 * w), "stft1": 3 * sin(t * 1.3), "ltft1": 4.5]))
        }
        samples = out
    }
}

enum Haptics {
    static func alarm() { AudioServicesPlaySystemSound(1005); UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func success() { AudioServicesPlaySystemSound(1025); UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

enum HealthScore {
    static func compute(codes: [FoundCode], readiness: ELMParser.Readiness?, voltage: Double) -> Int {
        var s = 100
        for c in codes {
            let w: Int
            switch c.info.severity { case .high: w = 25; case .medium: w = 12; case .low: w = 5 }
            s -= c.kind == .pending ? w / 2 : w
        }
        if readiness?.milOn == true { s -= 10 }
        s -= min(10, (readiness?.incomplete ?? 0) * 3)
        if voltage > 0 && voltage < 12.2 { s -= 8 }
        return max(0, min(100, s))
    }
}

enum Notifier {
    static func request() { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in } }
    static func heat(_ c: Double) {
        let n = UNMutableNotificationContent()
        n.title = L("حرارة المحرك عالية", "Engine temperature high")
        n.body = L("الحرارة \(Int(c))° — وقّف بمكان آمن وطفّي المكيف وخل المكينة تبرد. لا تفتح غطا الرديتر.", "Coolant \(Int(c))°. Pull over safely, switch off A/C and let it cool. Don't open the radiator cap.")
        n.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "heat", content: n, trigger: nil))
    }
    static func schedule(id: String, title: String, body: String, at date: Date) {
        let n = UNMutableNotificationContent(); n.title = title; n.body = body; n.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: n, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }
    static func cancel(_ id: String) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id]) }
}
