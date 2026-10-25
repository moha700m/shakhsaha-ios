import Foundation
import CoreLocation
import SwiftUI

/// GPS speed/trip/0-100 without any adapter. Speed comes from Core Location (honestly labelled as GPS).
@MainActor
final class GPSService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var speedKmh: Double = 0
    @Published var distanceKm: Double = 0
    @Published var running = false
    @Published var authorized = false
    @Published var maxSpeed: Double = 0
    @Published var accelArmed = false
    @Published var accelStart: Date?
    @Published var accelResult: Double?
    private let m = CLLocationManager()
    private var last: CLLocation?
    var startDate: Date?

    override init() {
        super.init()
        m.delegate = self; m.desiredAccuracy = kCLLocationAccuracyBestForNavigation; m.activityType = .automotiveNavigation
    }
    func start() { m.requestWhenInUseAuthorization(); m.startUpdatingLocation(); running = true; if startDate == nil { startDate = Date() } }
    func stop() { m.stopUpdatingLocation(); running = false }
    func reset() { distanceKm = 0; maxSpeed = 0; last = nil; startDate = Date() }
    func arm() { accelArmed = true; accelStart = nil; accelResult = nil }

    nonisolated func locationManagerDidChangeAuthorization(_ mgr: CLLocationManager) {
        let ok = mgr.authorizationStatus == .authorizedWhenInUse || mgr.authorizationStatus == .authorizedAlways
        Task { @MainActor in self.authorized = ok }
    }
    nonisolated func locationManager(_ mgr: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        Task { @MainActor in for l in locs { self.handle(l) } }
    }
    private func handle(_ l: CLLocation) {
        guard l.horizontalAccuracy >= 0, l.horizontalAccuracy < 30 else { return }
        let v = max(0, l.speed) * 3.6
        speedKmh = v; maxSpeed = max(maxSpeed, v)
        if let p = last, v > 2 { distanceKm += l.distance(from: p) / 1000 }
        last = l
        if accelArmed {
            if accelStart == nil && v > 1 { accelStart = l.timestamp }
            if let s = accelStart, v >= 100 { accelResult = l.timestamp.timeIntervalSince(s); accelArmed = false; Haptics.success() }
        }
    }
}

struct GPSTripView: View {
    @EnvironmentObject var gps: GPSService
    @EnvironmentObject var catalog: CatalogStore
    @EnvironmentObject var cars: VehicleStore
    @AppStorage("shakhsaha.l100") private var l100 = 9.0
    var body: some View {
        List {
            Section {
                HStack { Spacer(); VStack {
                    Text(String(format: "%.0f", gps.speedKmh)).font(.system(size: 72, weight: .heavy, design: .rounded)).monospacedDigit()
                    Text(L("كم/س (GPS)", "km/h (GPS)")).font(.caption)
                }; Spacer() }
            }
            Section(L("الرحلة", "Trip")) {
                row(L("المسافة", "Distance"), String(format: "%.2f km", gps.distanceKm))
                row(L("أعلى سرعة", "Max speed"), String(format: "%.0f km/h", gps.maxSpeed))
                Stepper(L("استهلاك سيارتك ‎\(String(format: "%.1f", l100)) لتر/١٠٠كم", "Your car uses \(String(format: "%.1f", l100)) L/100km"), value: $l100, in: 3...25, step: 0.5)
                let fuel = gps.distanceKm * l100 / 100, price = catalog.fuelPrice(cars.current.fuel)
                row(L("بنزين تقريبي", "Est. fuel"), String(format: "%.2f L", fuel))
                row(L("تكلفة تقريبية", "Est. cost"), String(format: L("%.2f ريال", "%.2f SAR"), fuel * price))
                Button(gps.running ? L("وقّف", "Stop") : L("ابدأ الرحلة", "Start trip")) { gps.running ? gps.stop() : gps.start() }
                Button(L("صفّر", "Reset")) { gps.reset() }
            }
            Section(L("٠-١٠٠ بالـ GPS", "0-100 via GPS")) {
                if let r = gps.accelResult { row("0-100", String(format: L("%.2f ثانية", "%.2f s"), r)) }
                else if gps.accelArmed { Text(gps.accelStart == nil ? L("جاهز، انطلق من وقوف", "Ready, launch from a stop") : L("يقيس…", "Timing…")) }
                Button(L("جهّز القياس", "Arm")) { gps.start(); gps.arm() }
                Text(L("الـ GPS يحدّث مرة بالثانية تقريباً فالدقة ±٠.٥ ثانية. مع قطعة OBD أدق. في مكان مغلق ونظامي فقط.",
                       "GPS updates ~1 Hz so accuracy is about ±0.5 s; an OBD adapter is more precise. Closed, legal venues only.")).font(.caption)
            }
            if !gps.authorized { Text(L("يحتاج إذن الموقع أثناء الاستخدام.", "Needs location permission while in use.")).font(.caption).foregroundStyle(Theme.warn) }
        }
        .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("رحلة GPS بدون قطعة", "GPS trip (no adapter)"))
    }
    func row(_ k: String, _ v: String) -> some View { HStack { Text(k); Spacer(); Text(v).bold().monospacedDigit() } }
}
