import SwiftUI
import Charts

struct DemoBadge: View {
    var body: some View {
        Text(L("تجريبي", "DEMO")).font(.caption2.bold()).padding(.horizontal, 8).padding(.vertical, 3)
            .background(Theme.terra.opacity(0.18), in: Capsule()).foregroundStyle(Theme.terra)
    }
}

struct LiveView: View {
    @EnvironmentObject var obd: OBDService
    @State private var editing = false
    @State private var csvURL: URL?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if !obd.connected { NotConnectedCard() }
                    if obd.isDemo { HStack { DemoBadge(); Text(L("قراءات تجريبية، مو من سيارتك", "Simulated values, not your car")).font(.caption); Spacer() } }
                    if obd.heatAlert { HeatBanner() }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(obd.dashboard, id: \.self) { id in
                            if let d = PIDs.def(id) {
                                Gauge2(title: d.name, value: obd.values[id] ?? 0, max: d.max, unit: d.unit, fmt: d.fmt, warn: d.warn ?? 1e9, low: d.low ?? -1)
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        Button { obd.recording ? obd.stopRecording() : obd.startRecording() } label: {
                            Label(obd.recording ? L("وقّف التسجيل", "Stop") : L("سجّل", "Record"), systemImage: obd.recording ? "stop.circle.fill" : "record.circle")
                                .frame(maxWidth: .infinity).frame(height: 44)
                        }.buttonStyle(.borderedProminent).tint(obd.recording ? Theme.warn : Theme.terra).disabled(!obd.connected)
                        NavigationLink { GraphsView() } label: { Label(L("الرسوم", "Graphs"), systemImage: "chart.xyaxis.line").frame(maxWidth: .infinity).frame(height: 44) }
                            .buttonStyle(.bordered).tint(Theme.terra)
                    }
                    HStack(spacing: 10) {
                        NavigationLink { HUDView() } label: { Label("HUD", systemImage: "rectangle.on.rectangle.angled").frame(maxWidth: .infinity).frame(height: 44) }
                        NavigationLink { AccelView() } label: { Label("0-100", systemImage: "stopwatch").frame(maxWidth: .infinity).frame(height: 44) }
                        NavigationLink { TripView() } label: { Label(L("الرحلة", "Trip"), systemImage: "fuelpump").frame(maxWidth: .infinity).frame(height: 44) }
                    }.buttonStyle(.bordered).tint(Theme.terra)
                    DisclaimerBanner()
                }.padding(16)
            }
            .background(Theme.sand.ignoresSafeArea())
            .navigationTitle(L("لوحة القراءات", "Dashboard"))
            .toolbar { ToolbarItem { Button { editing = true } label: { Image(systemName: "square.grid.2x2") } } }
            .sheet(isPresented: $editing) { DashboardEditor() }
            .onAppear { obd.startLive() }
        }
    }
}

struct NotConnectedCard: View {
    @EnvironmentObject var obd: OBDService
    @EnvironmentObject var catalog: CatalogStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("ما فيه قطعة متصلة", "No adapter connected"), systemImage: "antenna.radiowaves.left.and.right.slash").font(.headline)
            Text(L("القراءات المباشرة تحتاج قطعة OBD2. تقدر تجرّب كل شي بالوضع التجريبي.", "Live data needs an OBD2 adapter. Try everything in demo mode.")).font(.caption)
            Button(L("شغّل الوضع التجريبي", "Start demo mode")) { Task { await obd.connect(kind: .demo); await obd.fullScan(catalog: catalog.catalog); obd.startLive() } }
                .buttonStyle(.borderedProminent).tint(Theme.terra)
        }.foregroundStyle(Theme.ink).padding(14).frame(maxWidth: .infinity, alignment: .leading).softCard(18)
    }
}

struct DashboardEditor: View {
    @EnvironmentObject var obd: OBDService
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section(L("اللي في اللوحة (اسحب للترتيب)", "On dashboard (drag to reorder)")) {
                    ForEach(obd.dashboard, id: \.self) { id in Text(PIDs.def(id)?.name ?? id) }
                        .onMove { obd.dashboard.move(fromOffsets: $0, toOffset: $1) }
                        .onDelete { obd.dashboard.remove(atOffsets: $0) }
                }
                Section(L("أضف قراءة", "Add a reading")) {
                    ForEach(PIDs.all.filter { !obd.dashboard.contains($0.id) }) { d in
                        Button { obd.dashboard.append(d.id) } label: {
                            HStack { Text(d.name); Spacer(); if !obd.isSupported(d) { Text(L("سيارتك ما تدعمه", "Not supported")).font(.caption).foregroundStyle(.secondary) }; Image(systemName: "plus.circle.fill") }
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(L("خصّص اللوحة", "Customize")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("تم", "Done")) { dismiss() } } }
        }
    }
}

struct GraphsView: View {
    @EnvironmentObject var obd: OBDService
    @State private var pick: Set<String> = ["rpm", "speed", "coolant"]
    var keys: [String] { Array(Set(obd.samples.flatMap { $0.v.keys })).sorted() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if obd.samples.isEmpty {
                    Text(L("ما فيه تسجيل. سجّل من اللوحة، أو اعرض بيانات تجريبية.", "No recording yet. Record from the dashboard or view sample data.")).font(.subheadline)
                    Button(L("اعرض تسجيل تجريبي", "Show sample recording")) { obd.loadDemoSamples() }.buttonStyle(.borderedProminent).tint(Theme.terra)
                } else {
                    if obd.isDemo || !obd.connected { HStack { DemoBadge(); Text(L("بيانات تجريبية للتوضيح", "Sample data for illustration")).font(.caption) } }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(keys, id: \.self) { k in
                            Button(PIDs.def(k)?.name ?? k) { if pick.contains(k) { pick.remove(k) } else { pick.insert(k) } }
                                .buttonStyle(.bordered).tint(pick.contains(k) ? Theme.terra : .gray)
                        } }
                    }
                    ForEach(keys.filter { pick.contains($0) }, id: \.self) { k in
                        let pts = obd.samples.compactMap { s in s.v[k].map { (s.t, $0) } }
                        let vals = pts.map { $0.1 }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(PIDs.def(k)?.name ?? k).font(.headline)
                                Spacer()
                                if let mn = vals.min(), let mx = vals.max() {
                                    Text(L("أقل \(fmt(k, mn)) · أعلى \(fmt(k, mx)) · متوسط \(fmt(k, vals.reduce(0, +) / Double(vals.count)))",
                                           "min \(fmt(k, mn)) · max \(fmt(k, mx)) · avg \(fmt(k, vals.reduce(0, +) / Double(vals.count)))")).font(.caption2)
                                }
                            }
                            Chart(pts, id: \.0) { p in
                                LineMark(x: .value("t", p.0), y: .value(k, p.1)).foregroundStyle(Theme.terra).interpolationMethod(.catmullRom)
                            }.frame(height: 140)
                        }.padding(12).softCard(18)
                    }
                    ShareLink(item: obd.csv()) { Label(L("صدّر CSV", "Export CSV"), systemImage: "tablecells").frame(maxWidth: .infinity).frame(height: 46) }
                        .buttonStyle(.borderedProminent).tint(Theme.terra)
                }
            }.padding(16).foregroundStyle(Theme.ink)
        }
        .background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("الرسوم والسجل", "Graphs & logs"))
    }
    func fmt(_ k: String, _ v: Double) -> String { String(format: PIDs.def(k)?.fmt ?? "%.1f", v) }
}

struct HUDView: View {
    @EnvironmentObject var obd: OBDService
    @State private var mirrored = true
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                Text(String(format: "%.0f", obd.live.speed)).font(.system(size: 150, weight: .heavy, design: .rounded)).monospacedDigit()
                Text(L("كم/س", "km/h")).font(.title2)
                HStack(spacing: 30) {
                    Text(String(format: "%.0f rpm", obd.live.rpm))
                    Text(String(format: "%.0f°", obd.live.coolant)).foregroundStyle(obd.heatAlert ? .red : .green)
                }.font(.title.bold())
            }
            .foregroundStyle(.green)
            .scaleEffect(x: 1, y: mirrored ? -1 : 1)
        }
        .onTapGesture(count: 2) { mirrored.toggle() }
        .onAppear { obd.hudActive = true; obd.startLive(); UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { obd.hudActive = false; UIApplication.shared.isIdleTimerDisabled = false }
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden()
    }
}

struct AccelView: View {
    @EnvironmentObject var obd: OBDService
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "stopwatch").font(.system(size: 50)).foregroundStyle(Theme.terra)
            Text(String(format: "%.0f", obd.live.speed)).font(.system(size: 80, weight: .heavy, design: .rounded)).monospacedDigit()
            if let r = obd.accelResult { Text(L("٠-١٠٠: \(String(format: "%.2f", r)) ثانية", "0-100: \(String(format: "%.2f", r)) s")).font(.title.bold()) }
            else if obd.accelArmed { Text(obd.accelStart == nil ? L("جاهز… وقّف السيارة وانطلق", "Ready… start from a stop") : L("يقيس…", "Timing…")).font(.title3) }
            if let b = obd.accelBest { Text(L("أفضل وقت: \(String(format: "%.2f", b)) ث", "Best: \(String(format: "%.2f", b)) s")).font(.subheadline) }
            PrimaryButton(title: L("جهّز القياس", "Arm timer")) { obd.armAccel() }.disabled(!obd.connected)
            Text(L("قِس في مكان مغلق ومسموح فقط، لا تخالف أنظمة المرور. القياس تقريبي ويعتمد على سرعة رد القطعة.",
                   "Only on a closed, legal track. Never break traffic laws. Accuracy depends on adapter speed.")).font(.caption).multilineTextAlignment(.center)
            if obd.isDemo { DemoBadge() }
        }.padding(24).foregroundStyle(Theme.ink).frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.sand.ignoresSafeArea())
        .navigationTitle("0-100").onAppear { obd.startLive() }
    }
}

struct TripView: View {
    @EnvironmentObject var obd: OBDService
    @EnvironmentObject var catalog: CatalogStore
    @EnvironmentObject var cars: VehicleStore
    var body: some View {
        List {
            if obd.isDemo { DemoBadge() }
            row(L("المسافة", "Distance"), String(format: "%.2f km", obd.tripKm))
            row(L("البنزين المستهلك", "Fuel used"), String(format: "%.2f L", obd.tripFuelL))
            row(L("الاستهلاك الحالي", "Instant"), obd.instantL100.map { String(format: "%.1f L/100km", $0) } ?? String(format: "%.1f L/h", obd.fuelRateLh))
            row(L("متوسط الاستهلاك", "Average"), obd.avgL100.map { String(format: "%.1f L/100km · %.1f km/L", $0, 100 / max($0, 0.1)) } ?? "—")
            let price = catalog.fuelPrice(cars.current.fuel)
            row(L("تكلفة الرحلة", "Trip cost"), String(format: L("%.2f ريال (بنزين %@ بـ %.2f)", "%.2f SAR (%@ at %.2f)"), obd.tripFuelL * price, cars.current.fuel, price))
            if let s = obd.tripStart { row(L("بدأت", "Started"), s.formatted(date: .omitted, time: .shortened)) }
            Button(L("صفّر الرحلة", "Reset trip")) { obd.resetTrip() }
            Text(L("الاستهلاك محسوب تقريباً من حساس الهواء MAF أو معدّل الوقود، وممكن يختلف ±١٥٪.", "Consumption is estimated from MAF or fuel rate and may vary ±15%.")).font(.caption)
        }
        .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("كمبيوتر الرحلة", "Trip computer")).onAppear { obd.startLive() }
    }
    func row(_ k: String, _ v: String) -> some View { HStack { Text(k); Spacer(); Text(v).bold().monospacedDigit() } }
}

struct Gauge2: View {
    let title: String; let value: Double; let max: Double; let unit: String; let fmt: String; let warn: Double
    var low: Double = -1
    var bad: Bool { value >= warn || (low > 0 && value > 0 && value < low) }
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().trim(from: 0.15, to: 0.85).stroke(Theme.ink.opacity(0.08), style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(90))
                Circle().trim(from: 0.15, to: 0.15 + 0.7 * min(1, Swift.max(0, value / max)))
                    .stroke(bad ? Theme.warn : Theme.terra, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(90))
                    .animation(.easeOut(duration: 0.4), value: value)
                VStack(spacing: 0) {
                    Text(String(format: fmt, value)).font(.system(size: 28, weight: .heavy, design: .rounded)).monospacedDigit()
                    Text(unit).font(.caption2).foregroundStyle(Theme.ink.opacity(0.6))
                }
            }.padding(8)
            Text(title).font(.caption.bold())
        }.foregroundStyle(Theme.ink).padding(10).frame(minHeight: 150).softCard(22)
    }
}
