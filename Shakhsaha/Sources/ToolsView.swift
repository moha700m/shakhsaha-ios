import SwiftUI
import CoreImage.CIFilterBuiltins

struct ToolsView: View {
    @EnvironmentObject var obd: OBDService
    var body: some View {
        NavigationStack {
            List {
                Section(L("فحص احترافي", "Pro scan")) {
                    link(L("الفحص الشامل لكل الأنظمة", "Full-system scan"), "cpu", FullScanView())
                }
                Section(L("المختبر", "Lab")) {
                    link(L("حساسات الأكسجين وتعديل الوقود", "O2 sensors & fuel trims"), "aqi.medium", SensorsView(only: ["o2s1", "o2s2", "stft1", "ltft1", "stft2", "ltft2", "maf"]))
                    link(L("عدّاد التفويت واختبارات Mode 06", "Misfire counters & Mode 06"), "testtube.2", Mode06View())
                    link(L("جاهزية الفحص الدوري", "Readiness monitors"), "gauge.with.needle", ReadinessView())
                    link(L("سجل صحة السيارة", "Health score history"), "chart.line.uptrend.xyaxis", ScoreHistoryView())
                }
                Section(L("بدون قطعة", "No adapter needed")) {
                    link(L("صوّر طبلونك", "Snap your dashboard"), "camera.viewfinder", DashPhotoView())
                    link(L("رحلة و٠-١٠٠ بالـ GPS", "GPS trip & 0-100"), "location.north.line", GPSTripView())
                    link(L("ابحث عن كود عطل", "Look up a fault code"), "magnifyingglass", DTCLookupView())
                    link(L("مدرّب الفحص الدوري", "Inspection (MVPI) coach"), "checkmark.shield", CoachView())
                    link(L("أسعار الورش حسب المدينة", "Workshop prices by city"), "building.2", GaragePricesView())
                    link(L("تقرير سيارة مستعملة", "Used-car buyer report"), "doc.text.magnifyingglass", UsedCarReportView())
                    link(L("بطاقة صحة السيارة (سناب/إكس)", "Car health card (Snap/X)"), "rectangle.portrait.on.rectangle.portrait", HealthCardView())
                    link(L("نصائح الحر والصيف", "Heat-wave tips"), "sun.max", HeatTipsView())
                    link(L("سياراتي", "My cars"), "car.2", VehiclesView())
                    link(L("صديق يفحص معك", "Scan with a friend"), "person.2", InviteView())
                }
                Section(L("مع القطعة (أو الوضع التجريبي)", "With adapter (or demo)")) {
                    link(L("كل الحساسات", "All sensors"), "list.bullet.rectangle", SensorsView())
                    link(L("لقطة التجميد", "Freeze frame"), "camera.metering.spot", FreezeFrameView())
                    link(L("كمبيوتر الرحلة والاستهلاك", "Trip & fuel"), "fuelpump", TripView())
                    link(L("تسارع ٠-١٠٠", "0-100 timer"), "stopwatch", AccelView())
                    link(L("وضع HUD للزجاج", "Windshield HUD"), "rectangle.on.rectangle.angled", HUDView())
                    link(L("الرسوم والسجل CSV", "Graphs & CSV logs"), "chart.xyaxis.line", GraphsView())
                }
            }
            .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
            .navigationTitle(L("الأدوات", "Tools"))
        }
    }
    func link<V: View>(_ t: String, _ i: String, _ v: V) -> some View {
        NavigationLink { v } label: { Label(t, systemImage: i).foregroundStyle(Theme.ink) }
    }
}

struct DTCLookupView: View {
    @State private var q = ""
    var results: [DTCInfo] {
        let u = q.uppercased().trimmingCharacters(in: .whitespaces)
        if u.isEmpty { return DTCDatabase.all.values.sorted { $0.code < $1.code } }
        var r = DTCDatabase.all.values.filter { $0.code.contains(u) || $0.titleAr.contains(q) || $0.titleEn.uppercased().contains(u) }.sorted { $0.code < $1.code }
        if r.isEmpty, u.range(of: "^[PCBU][0-3][0-9A-F]{3}$", options: .regularExpression) != nil { r = [DTCDatabase.info(u)] }
        return r
    }
    var body: some View {
        List(results) { i in
            NavigationLink { DTCDetailView(code: FoundCode(code: i.code, kind: .stored), lookupOnly: true) } label: {
                HStack { Text(i.code).font(.headline.monospaced()).foregroundStyle(Theme.terra); Text(i.title).font(.subheadline) }
            }
        }
        .searchable(text: $q, prompt: L("اكتب الكود مثل P0420 أو كلمة مثل حرارة", "Type a code like P0420 or a word"))
        .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("دليل الأكواد", "Code library"))
    }
}

struct SensorsView: View {
    @EnvironmentObject var obd: OBDService
    var only: [String]? = nil
    var body: some View {
        List {
            if !obd.connected { NotConnectedCard() }
            if obd.isDemo { DemoBadge() }
            ForEach(PIDs.all.filter { only?.contains($0.id) ?? true }) { d in
                HStack {
                    Text(d.name)
                    Spacer()
                    if let v = obd.values[d.id] { Text(String(format: d.fmt, v) + " " + d.unit).bold().monospacedDigit() }
                    else { Text(obd.isSupported(d) ? "…" : L("غير مدعوم", "n/a")).foregroundStyle(.secondary) }
                }
            }
            if only != nil {
                Text(L("تعديل الوقود الطويل فوق +١٠٪ يعني المكينة تضيف بنزين لتعويض هواء زايد (تهريب أو MAF وسخ). تحت -١٠٪ يعني خليط غني. حساس الأكسجين الأمامي لازم يتذبذب بين ٠.١ و٠.٩ فولت.",
                       "LTFT above +10% means the ECU adds fuel for extra air (leak or dirty MAF); below -10% means rich. Upstream O2 should switch between 0.1 and 0.9 V.")).font(.caption)
            }
        }
        .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
        .navigationTitle(only == nil ? L("كل الحساسات", "All sensors") : L("الأكسجين والوقود", "O2 & fuel trims"))
        .onAppear {
            if let o = only { for id in o where !obd.dashboard.contains(id) { obd.dashboard.append(id) } }
            else { for d in PIDs.all where !obd.dashboard.contains(d.id) && obd.isSupported(d) && obd.isDemo { _ = d } }
            obd.stopLive(); obd.startLive()
        }
    }
}

struct FreezeFrameView: View {
    @EnvironmentObject var obd: OBDService
    var body: some View {
        List {
            if !obd.connected { NotConnectedCard() }
            if obd.isDemo { DemoBadge() }
            if let c = obd.freezeFrameCode {
                Section(L("العطل اللي سبّب اللقطة", "Triggering code")) {
                    NavigationLink { DTCDetailView(code: FoundCode(code: c, kind: .stored)) } label: { Text("\(c) — \(DTCDatabase.info(c).title)") }
                }
                Section(L("حالة الحساسات لحظة العطل", "Sensors at the moment of fault")) {
                    ForEach(obd.freezeValues.keys.sorted(), id: \.self) { k in
                        if let d = PIDs.def(k), let v = obd.freezeValues[k] { HStack { Text(d.name); Spacer(); Text(String(format: d.fmt, v) + " " + d.unit).bold() } }
                    }
                }
            } else { Text(L("ما فيه لقطة تجميد محفوظة.", "No freeze frame stored.")) }
            Button(L("اقرأ من جديد", "Read again")) { Task { await obd.readFreezeFrame() } }.disabled(!obd.connected)
        }
        .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("لقطة التجميد", "Freeze frame"))
        .task { if obd.connected && obd.freezeValues.isEmpty { await obd.readFreezeFrame() } }
    }
}

struct Mode06View: View {
    @EnvironmentObject var obd: OBDService
    @State private var loading = false
    var body: some View {
        List {
            if !obd.connected { NotConnectedCard() }
            if obd.isDemo { DemoBadge() }
            Text(L("كمبيوتر السيارة يختبر نفسه باستمرار. هنا نتيجة كل اختبار مع الحد الأدنى والأعلى، واللي برّا الحد يدلّ على قطعة بتخرب قبل ما تولّع اللمبة.",
                   "The ECU continuously self-tests. Each result with its limits; out-of-range hints at a part failing before the light comes on.")).font(.caption)
            ForEach(obd.mode06) { r in
                HStack {
                    Image(systemName: r.pass ? "checkmark.circle.fill" : "xmark.octagon.fill").foregroundStyle(r.pass ? Theme.green : Theme.warn)
                    VStack(alignment: .leading) {
                        Text(r.monitorName).font(.subheadline.bold())
                        Text(String(format: "TID %02X · %@ %d · min %d · max %d", r.tid, L("القيمة", "value"), r.value, r.min, r.max)).font(.caption.monospaced())
                    }
                }
            }
            Button(loading ? L("يقرأ…", "Reading…") : L("اقرأ Mode 06", "Read Mode 06")) {
                Task { loading = true; await obd.readMode06(); loading = false }
            }.disabled(!obd.connected || loading)
        }
        .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
        .navigationTitle("Mode 06")
    }
}

struct CoachView: View {
    @EnvironmentObject var obd: OBDService
    @AppStorage("shakhsaha.coach") private var doneRaw = ""
    let steps: [(String, String)] = [
        ("صلّح أي عطل يشغّل لمبة المكينة، وتأكد إنها مطفية.", "Fix anything lighting the check-engine lamp."),
        ("لا تمسح الأكواد ولا تفصل البطارية قبل الفحص بأسبوع، يصفّر الجاهزية.", "Don't clear codes or disconnect the battery within a week of the test."),
        ("سوّ دورة قيادة: تشغيل بارد، سلانسيه دقيقتين، طريق سريع ٨٠-١٠٠ لمدة ١٥ دقيقة، ثم زحمة مع وقفات.", "Do a drive cycle: cold start, 2-min idle, 15 min at 80–100 km/h, then stop-and-go."),
        ("خل البنزين بين ربع وثلاث أرباع (يساعد اختبار EVAP).", "Keep fuel between 1/4 and 3/4 (helps EVAP test)."),
        ("افحص الأنوار والإشارات والمساحات والكفرات والفرامل اليدوية.", "Check lights, indicators, wipers, tires and parking brake."),
        ("تأكد من الشكمان ما فيه دخان أو صوت تهريب، وزجاجك ما فيه شرخ كبير.", "No visible smoke or exhaust leaks; no large windshield cracks."),
        ("احجز موعدك من منصة الفحص الدوري وخذ الاستمارة سارية.", "Book via the official MVPI platform and bring a valid registration."),
    ]
    var done: Set<Int> { Set(doneRaw.split(separator: ",").compactMap { Int($0) }) }
    var body: some View {
        List {
            Section {
                HStack {
                    Image("Engine").resizable().scaledToFill().frame(width: 70, height: 70).clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading) {
                        Text(L("جاهزيتك: \(done.count)/\(steps.count)", "Progress: \(done.count)/\(steps.count)")).font(.headline)
                        if let r = obd.readiness {
                            Text(L("كمبيوتر السيارة: \(r.monitors.count - r.incomplete)/\(r.monitors.count) مكتمل", "ECU monitors: \(r.monitors.count - r.incomplete)/\(r.monitors.count) complete")).font(.caption)
                        } else { Text(L("اتصل بالقطعة عشان نقرأ الجاهزية الفعلية", "Connect to read real monitors")).font(.caption) }
                    }
                }
            }
            Section(L("خطوات قبل الفحص الدوري", "Steps before inspection")) {
                ForEach(steps.indices, id: \.self) { i in
                    Button { toggle(i) } label: {
                        HStack(alignment: .top) {
                            Image(systemName: done.contains(i) ? "checkmark.circle.fill" : "circle").foregroundStyle(done.contains(i) ? Theme.green : Theme.ink.opacity(0.4))
                            Text(L(steps[i].0, steps[i].1)).foregroundStyle(Theme.ink)
                        }
                    }
                }
            }
            Text(L("المدرّب إرشادي، ونتيجة الفحص الرسمي تعتمد على مركز الفحص.", "Guidance only; the official result depends on the inspection center.")).font(.caption)
        }
        .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("مدرّب الفحص الدوري", "MVPI coach"))
    }
    func toggle(_ i: Int) { var d = done; if d.contains(i) { d.remove(i) } else { d.insert(i) }; doneRaw = d.map(String.init).joined(separator: ",") }
}

struct GaragePricesView: View {
    @EnvironmentObject var catalog: CatalogStore
    @EnvironmentObject var cars: VehicleStore
    @State private var code = "P0420"
    var info: DTCInfo { DTCDatabase.info(code.uppercased()) }
    var body: some View {
        List {
            Section {
                TextField(L("كود العطل", "Fault code"), text: $code).textInputAutocapitalization(.characters).font(.headline.monospaced())
                Text(info.title).font(.subheadline)
            }
            let base = catalog.cost(for: info)
            Section(L("ورشة عادية حسب المدينة", "Independent workshop by city")) {
                ForEach(catalog.cities, id: \.0) { c in
                    let f = catalog.factor(c.0)
                    HStack {
                        Text(c.1).fontWeight(c.0 == cars.current.city ? .bold : .regular)
                        Spacer()
                        Text(L("\(Int(Double(base.min) * f)) - \(Int(Double(base.max) * f)) ريال", "\(Int(Double(base.min) * f))–\(Int(Double(base.max) * f)) SAR")).monospacedDigit()
                    }
                }
            }
            Section(L("الوكالة (تقريباً)", "Dealer (approx.)")) {
                let f = catalog.factor(cars.current.city) * catalog.dealer
                Text(L("\(Int(Double(base.min) * f)) - \(Int(Double(base.max) * f)) ريال", "\(Int(Double(base.min) * f))–\(Int(Double(base.max) * f)) SAR")).bold()
            }
            Text(L("أسعار تقريبية من كتالوج يتحدّث عن بعد (نسخة \(catalog.catalog.version))، تشمل القطع والشغل وتختلف حسب الموديل.",
                   "Estimates from a remotely-updated catalog (v\(catalog.catalog.version)), parts + labor, vary by model.")).font(.caption)
        }
        .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("مقارنة الأسعار", "Price compare"))
    }
}

struct HeatTipsView: View {
    @EnvironmentObject var catalog: CatalogStore
    @EnvironmentObject var obd: OBDService
    var body: some View {
        List {
            Image("Heat").resizable().scaledToFill().frame(height: 160).clipped().listRowInsets(EdgeInsets())
            if obd.connected {
                Section(L("الحين", "Now")) {
                    HStack { Text(L("حرارة الماء", "Coolant")); Spacer(); Text(String(format: "%.0f°", obd.live.coolant)).bold() }
                    HStack { Text(L("البطارية", "Battery")); Spacer(); Text(String(format: "%.1fV", obd.live.voltage)).bold().foregroundStyle(obd.live.voltage > 0 && obd.live.voltage < 12.2 ? Theme.warn : Theme.ink) }
                    if let a = obd.values["ambient"] { HStack { Text(L("حرارة الجو", "Ambient")); Spacer(); Text(String(format: "%.0f°", a)).bold() } }
                }
            }
            Section(L("نصائح", "Tips")) { ForEach(catalog.heatTips + catalog.tips, id: \.self) { Text($0) } }
            Text(L("البطارية وهي طافية: فوق ١٢.٦ ممتازة، ١٢.٢-١٢.٤ ضعيفة، تحت ١٢ غيّرها. وهي شغّالة: ١٣.٥-١٤.٧ يعني الدينمو يشحن.",
                   "Engine off: >12.6 V great, 12.2–12.4 weak, <12 replace. Running: 13.5–14.7 V means charging OK.")).font(.caption)
        }
        .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("الحر والبطارية", "Heat & battery"))
    }
}

struct VehiclesView: View {
    @EnvironmentObject var cars: VehicleStore
    @EnvironmentObject var catalog: CatalogStore
    var body: some View {
        List {
            ForEach($cars.cars) { $c in
                Section {
                    HStack {
                        TextField(L("الاسم", "Name"), text: $c.name).font(.headline)
                        if cars.currentId == c.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green) }
                        else { Button(L("اختر", "Select")) { cars.currentId = c.id }.buttonStyle(.bordered) }
                    }
                    TextField(L("الشركة", "Make"), text: $c.make)
                    TextField(L("الموديل", "Model"), text: $c.model)
                    Stepper(L("السنة \(String(c.year))", "Year \(String(c.year))"), value: $c.year, in: 1996...2027)
                    TextField("VIN", text: $c.vin).textInputAutocapitalization(.characters).font(.body.monospaced())
                    TextField(L("العداد (كم)", "Odometer (km)"), value: $c.odometer, format: .number).keyboardType(.numberPad)
                    Picker(L("البنزين", "Fuel"), selection: $c.fuel) { Text("91").tag("91"); Text("95").tag("95"); Text(L("ديزل", "Diesel")).tag("diesel") }
                    Picker(L("المدينة", "City"), selection: $c.city) { ForEach(catalog.cities, id: \.0) { Text($0.1).tag($0.0) } }
                    if cars.cars.count > 1 { Button(L("حذف السيارة", "Delete car"), role: .destructive) { cars.remove(c) } }
                }
            }
            Button { cars.add(Vehicle(name: L("سيارة \(cars.cars.count + 1)", "Car \(cars.cars.count + 1)"))) } label: { Label(L("أضف سيارة", "Add car"), systemImage: "plus") }
        }
        .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("سياراتي", "My cars"))
    }
}

struct InviteView: View {
    var text: String {
        L("عندي قطعة OBD وتطبيق «شخّصها» يشرح أعطال السيارة بالعربي مع سعر التصليح بالريال. تعال نفحص سيارتك ببلاش قبل الصيانة أو قبل ما تشتري مستعمل 🚗",
          "I've got an OBD adapter and the Shakhsaha app that explains car faults with SAR repair prices. Let's scan your car for free before service or a used-car purchase 🚗")
    }
    var body: some View {
        VStack(spacing: 18) {
            Image("Adapter").resizable().scaledToFill().frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 24))
            Text(L("صديق يفحص معك", "Scan with a friend")).font(.title.bold())
            Text(L("قطعة وحدة تكفي الشلة. ادعُ صديقك، ركّب القطعة في سيارته، وطلّع له تقرير يشاركه.", "One adapter is enough for the whole group. Invite a friend, plug in, and share their report.")).multilineTextAlignment(.center)
            ShareLink(item: text) { Label(L("ادعُ صديق", "Invite a friend"), systemImage: "person.badge.plus").frame(maxWidth: .infinity).frame(height: 52) }
                .buttonStyle(.borderedProminent).tint(Theme.terra)
            Spacer()
        }.padding(20).foregroundStyle(Theme.ink).background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("دعوة", "Invite"))
    }
}

enum QR {
    static func image(_ s: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator(); f.message = Data(s.utf8); f.correctionLevel = "M"
        guard let o = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(o, from: o.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

import Charts
struct ScoreHistoryView: View {
    @EnvironmentObject var obd: OBDService
    var body: some View {
        List {
            if obd.history.isEmpty { Text(L("ما فيه فحوصات محفوظة بعد.", "No saved scans yet.")) }
            else {
                Chart(obd.history.reversed()) { h in
                    LineMark(x: .value("d", h.date), y: .value("score", h.score)).foregroundStyle(Theme.terra)
                    PointMark(x: .value("d", h.date), y: .value("score", h.score)).foregroundStyle(Theme.terra)
                }.chartYScale(domain: 0...100).frame(height: 180)
                ForEach(obd.history) { h in
                    HStack { Text(h.date.formatted(date: .abbreviated, time: .shortened)); Spacer(); Text("\(h.score)").bold(); Text(L("\(h.codes.count) عطل", "\(h.codes.count) codes")).font(.caption) }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("سجل الصحة", "Health history"))
    }
}
