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

@MainActor
final class OBDService: ObservableObject {
    @Published var state: ConnState = .idle
    @Published var isDemo = false
    @Published var codes: [FoundCode] = []
    @Published var readiness: ELMParser.Readiness?
    @Published var vin: String?
    @Published var freezeFrameCode: String?
    @Published var live = LiveData()
    @Published var scanning = false
    @Published var scanProgress: Double = 0
    @Published var lastScan: ScanResult?
    @Published var history: [ScanResult] = []
    @Published var heatAlert = false
    @Published var passengerMode = false
    var heatLimit: Double = 105

    private var transport: OBDTransport?
    private var liveTask: Task<Void, Never>?
    private let histKey = "shakhsaha.history"

    init() {
        if let d = UserDefaults.standard.data(forKey: histKey), let h = try? JSONDecoder().decode([ScanResult].self, from: d) {
            history = h; lastScan = h.first
        }
    }

    var connected: Bool { if case .connected = state { return true }; return false }
    var drivingLocked: Bool { live.speed > 10 && !passengerMode }

    func connect(demo: Bool) async {
        state = .connecting
        isDemo = demo
        let t: OBDTransport = demo ? DemoTransport() : BLETransport()
        do {
            try await t.open()
            for c in ["ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0"] { _ = try await t.send(c) }
            let probe = try await t.send("0100")
            if ELMParser.isError(probe) && !demo { throw OBDError.timeout }
            transport = t
            state = .connected(t.name)
        } catch {
            t.close()
            state = .failed(error.localizedDescription)
        }
    }

    func disconnect() {
        liveTask?.cancel(); transport?.close(); transport = nil; state = .idle
    }

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
            scanProgress = Double(i + 1) / 7
        }
        codes = found
        if let r = try? await t.send("0101") { readiness = ELMParser.readiness(r) }
        scanProgress = 4 / 7
        if let r = try? await t.send("0902") { vin = ELMParser.vin(r) }
        scanProgress = 5 / 7
        if let r = try? await t.send("020200"), let d = ELMParser.pidData(r, mode: 0x42, pid: 0x02), d.count >= 2, d[0] | d[1] != 0 {
            freezeFrameCode = ELMParser.dtcString(d[0], d[1])
        } else { freezeFrameCode = nil }
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

    /// Mode 04: clears stored fault memory only. No other writes/coding are ever sent.
    func clearCodes(catalog: RemoteCatalog) async {
        guard let t = transport else { return }
        _ = try? await t.send("04")
        await fullScan(catalog: catalog)
    }

    func startLive() {
        guard let t = transport, liveTask == nil else { return }
        liveTask = Task { [weak self] in
            let pids: [ELMParser.PID] = [.rpm, .speed, .coolant, .throttle, .voltage, .load, .intake, .fuelLevel]
            while !Task.isCancelled {
                for p in pids {
                    guard !Task.isCancelled else { break }
                    let cmd = String(format: "01%02X", p.rawValue)
                    guard let r = try? await t.send(cmd), let d = ELMParser.pidData(r, pid: p.rawValue), let v = ELMParser.decode(p, d) else { continue }
                    await MainActor.run { self?.apply(p, v) }
                }
            }
        }
    }

    func stopLive() { liveTask?.cancel(); liveTask = nil }

    private func apply(_ p: ELMParser.PID, _ v: Double) {
        switch p {
        case .rpm: live.rpm = v
        case .speed: live.speed = v
        case .coolant:
            live.coolant = v
            if v >= heatLimit && !heatAlert { heatAlert = true; Notifier.heat(v) }
            if v < heatLimit - 5 { heatAlert = false }
        case .throttle: live.throttle = v
        case .voltage: live.voltage = v
        case .load: live.load = v
        case .intake: live.intake = v
        case .fuelLevel: live.fuel = v
        default: break
        }
    }
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
