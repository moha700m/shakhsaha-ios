import SwiftUI

struct FullScanView: View {
    @EnvironmentObject var obd: OBDService
    @EnvironmentObject var catalog: CatalogStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !obd.connected { NotConnectedCard() }
                if obd.isDemo { HStack { DemoBadge(); Text(L("نتائج تجريبية", "Simulated results")).font(.caption) } }
                Text(L("نخاطب كل كمبيوتر في السيارة على حدة (CAN) ونطلب أعطاله. الكمبيوترات اللي ما ترد ممكن تحتاج جهاز وكالة، وما نخترع لها نتيجة.",
                       "We address each control module on CAN and request its codes. Modules that don't answer may need dealer tools; we never invent results.")).font(.caption)
                PrimaryButton(title: obd.moduleScanning ? L("جاري الفحص الشامل…", "Scanning all systems…") : L("ابدأ الفحص الشامل", "Start full-system scan")) {
                    Task { await obd.fullScan(catalog: catalog.catalog); await obd.fullSystemScan() }
                }.disabled(!obd.connected || obd.moduleScanning)
                ForEach(obd.modules) { m in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            Image(m.module.img).resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading) {
                                Text(m.module.name).font(.subheadline.bold())
                                Text("CAN \(m.module.header)").font(.caption2.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            status(m.status)
                        }
                        ForEach(m.codes, id: \.self) { c in
                            NavigationLink { DTCDetailView(code: FoundCode(code: c, kind: .stored)) } label: {
                                HStack { Text(c).font(.caption.monospaced().bold()).foregroundStyle(Theme.terra); Text(DTCDatabase.info(c).title).font(.caption); Spacer() }
                            }.buttonStyle(.plain)
                        }
                    }.foregroundStyle(Theme.ink).padding(12).softCard(16)
                }
                if !obd.modules.isEmpty && !obd.moduleScanning {
                    let total = obd.modules.reduce(0) { $0 + $1.codes.count }
                    let silent = obd.modules.filter { $0.status == .noResponse }.count
                    Text(L("المجموع: \(total) عطل · \(silent) كمبيوتر ما رد (عادي لبعض السيارات مع ELM327)", "Total: \(total) codes · \(silent) modules silent (normal on some cars with ELM327)")).font(.footnote.bold())
                }
                DisclaimerBanner()
            }.padding(16)
        }
        .background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("الفحص الشامل", "Full-system scan"))
    }
    @ViewBuilder func status(_ s: ModuleStatus) -> some View {
        switch s {
        case .pending: Text("—").foregroundStyle(.secondary)
        case .scanning: ProgressView()
        case .ok(let n): Text(n == 0 ? L("سليم ✓", "OK ✓") : L("\(n) عطل", "\(n) codes")).font(.caption.bold()).foregroundStyle(n == 0 ? Theme.green : Theme.warn)
        case .noResponse: Text(L("ما رد", "No response")).font(.caption).foregroundStyle(.secondary)
        case .generic: Text(L("OBD عام", "Generic OBD")).font(.caption.bold()).foregroundStyle(Theme.terra)
        }
    }
}

struct UsedCarReportView: View {
    @EnvironmentObject var obd: OBDService
    @EnvironmentObject var catalog: CatalogStore
    @EnvironmentObject var cars: VehicleStore
    @State private var vin = ""
    @State private var odo = ""
    @State private var price = ""
    @State private var notes = ""
    @State private var checks: Set<Int> = []
    @State private var img: Image?
    let items: [(String, String)] = [("البودي بدون صدمات أو صبغ", "Body free of damage/repaint"), ("المكينة بدون تهريب زيت", "No engine oil leaks"),
        ("القير ينقل ناعم", "Smooth gear shifts"), ("المكيف بارد", "A/C blows cold"), ("الكفرات تاريخها حديث", "Recent tire dates"),
        ("ما فيه دخان من الشكمان", "No exhaust smoke"), ("الفرامل ما تصفّر", "Quiet brakes"), ("الاستمارة والفحص ساريين", "Valid registration & MVPI")]
    var text: String {
        var s = L("تقرير فحص سيارة مستعملة — شخّصها\n", "Used-car check — Shakhsaha\n")
        if !vin.isEmpty { s += "VIN: \(vin)\n" }
        if !odo.isEmpty { s += L("العداد: \(odo) كم\n", "Odometer: \(odo) km\n") }
        if let sc = obd.lastScan { s += L("الصحة: \(sc.score)/100 · أعطال: \(sc.codes.count)\n", "Health: \(sc.score)/100 · codes: \(sc.codes.count)\n") }
        s += L("فحص بالنظر: \(checks.count)/\(items.count)\n", "Visual checks: \(checks.count)/\(items.count)\n")
        if !notes.isEmpty { s += notes + "\n" }
        return s
    }
    var body: some View {
        Form {
            Section(L("السيارة", "Vehicle")) {
                TextField("VIN", text: $vin).textInputAutocapitalization(.characters).font(.body.monospaced())
                if VINDecoder.isValid(vin) { Text([VINDecoder.make(vin), VINDecoder.year(vin).map(String.init)].compactMap { $0 }.joined(separator: " · ")).font(.caption) }
                TextField(L("العداد (كم)", "Odometer (km)"), text: $odo).keyboardType(.numberPad)
                TextField(L("السعر المطلوب (ريال)", "Asking price (SAR)"), text: $price).keyboardType(.numberPad)
            }
            Section(L("فحص بالنظر", "Visual checklist")) {
                ForEach(items.indices, id: \.self) { i in
                    Toggle(L(items[i].0, items[i].1), isOn: Binding(get: { checks.contains(i) }, set: { v in if v { checks.insert(i) } else { checks.remove(i) } }))
                }
            }
            Section(L("ملاحظات", "Notes")) { TextField(L("أي شي لاحظته", "Anything noticed"), text: $notes, axis: .vertical) }
            Section(L("من كمبيوتر السيارة", "From the car computer")) {
                if obd.lastScan == nil { Text(L("ما فيه فحص بالقطعة بعد. التقرير بيطلع يدوي فقط.", "No adapter scan yet. Report will be manual only.")).font(.caption) }
                else { Text(L("آخر فحص: \(obd.lastScan!.score)/100 · \(obd.codes.count) عطل", "Last scan: \(obd.lastScan!.score)/100 · \(obd.codes.count) codes"))
                    if obd.isDemo { DemoBadge() } }
            }
            Section {
                if let img { ShareLink(item: img, preview: SharePreview(L("تقرير سيارة", "Car report"), image: img)) { Label(L("شارك التقرير مع QR", "Share report with QR"), systemImage: "qrcode") } }
                ShareLink(item: text) { Label(L("شارك كنص", "Share as text"), systemImage: "text.bubble") }
                Button(L("جهّز صورة التقرير", "Render report image")) { render() }
            }
        }
        .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("تقرير مستعمل", "Used-car report"))
        .onAppear { if vin.isEmpty { vin = obd.vin ?? cars.current.vin }; if odo.isEmpty && cars.current.odometer > 0 { odo = "\(cars.current.odometer)" } }
    }
    @MainActor func render() {
        let qr = QR.image(text)
        let v = VStack(alignment: .leading, spacing: 10) {
            ReportCard(scan: obd.lastScan, codes: obd.codes, readiness: obd.readiness, catalog: catalog.catalog)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if !odo.isEmpty { Text(L("العداد: \(odo) كم", "Odometer: \(odo) km")).font(.caption.bold()) }
                    if !price.isEmpty { Text(L("السعر: \(price) ريال", "Price: \(price) SAR")).font(.caption) }
                    Text(L("فحص بالنظر \(checks.count)/\(items.count)", "Visual \(checks.count)/\(items.count)")).font(.caption)
                    if !notes.isEmpty { Text(notes).font(.caption2) }
                }
                Spacer()
                if let qr { Image(uiImage: qr).interpolation(.none).resizable().frame(width: 110, height: 110) }
            }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 16))
        }.padding(16).frame(width: 400).background(Theme.sand).foregroundStyle(Theme.ink).appLayout()
        let r = ImageRenderer(content: v); r.scale = 3
        if let u = r.uiImage { img = Image(uiImage: u) }
    }
}

struct HealthCardView: View {
    @EnvironmentObject var obd: OBDService
    @EnvironmentObject var cars: VehicleStore
    @State private var img: Image?
    var card: some View {
        ZStack {
            Image("Hero").resizable().scaledToFill().frame(width: 360, height: 640).clipped()
            LinearGradient(colors: [.clear, Theme.sand.opacity(0.95)], startPoint: .top, endPoint: .center)
            VStack(spacing: 14) {
                Spacer()
                Text(cars.current.name).font(.system(size: 30, weight: .heavy, design: .rounded))
                ScoreRing(score: obd.lastScan?.score).scaleEffect(1.5).frame(height: 170)
                Text(L("صحة سيارتي", "My car's health")).font(.title3.bold())
                Text(obd.codes.isEmpty ? L("ما فيها ولا عطل 💪", "Zero faults 💪") : L("\(obd.codes.count) عطل وأعرف وش أسوي", "\(obd.codes.count) faults and I know the fix")).font(.headline)
                if obd.isDemo { DemoBadge() }
                Text(L("فحصتها بـ «شخّصها»", "Checked with Shakhsaha")).font(.caption.bold()).foregroundStyle(Theme.terra)
                Spacer().frame(height: 30)
            }.foregroundStyle(Theme.ink).padding(24)
        }.frame(width: 360, height: 640).appLayout()
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                card.scaleEffect(0.8).frame(width: 288, height: 512).clipShape(RoundedRectangle(cornerRadius: 24))
                if let img { ShareLink(item: img, preview: SharePreview(L("صحة سيارتي", "My car health"), image: img)) { Label(L("شارك سناب / إكس / ستوري", "Share to Snap / X / Story"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).frame(height: 50) }.buttonStyle(.borderedProminent).tint(Theme.terra) }
                if obd.lastScan == nil { Text(L("سوّ فحص أول عشان تطلع النتيجة الحقيقية.", "Scan first to show a real score.")).font(.caption) }
            }.padding(16)
        }
        .background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("بطاقة الصحة", "Health card"))
        .task { let r = ImageRenderer(content: card); r.scale = 3; if let u = r.uiImage { img = Image(uiImage: u) } }
    }
}

struct MechanicCard: View {
    let info: DTCInfo
    let cost: CostRange
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "person.wave.2.fill").foregroundStyle(Theme.terra); Text(L("وش تقول للميكانيكي", "What to tell the mechanic")).font(.headline) }
            Text(info.code).font(.system(size: 40, weight: .heavy, design: .monospaced)).foregroundStyle(Theme.terra)
            Text(info.title).font(.title3.bold())
            Text(DTCDatabase.mechanicScript(info)).font(.body)
            Text(L("السعر المعقول تقريباً: \(cost.min)-\(cost.max) ريال", "Fair price approx.: \(cost.min)–\(cost.max) SAR")).font(.subheadline.bold())
            Text(L("شخّصها · تقديري", "Shakhsaha · estimate")).font(.caption2).foregroundStyle(Theme.ink.opacity(0.5))
        }.foregroundStyle(Theme.ink).padding(20).frame(width: 380, alignment: .leading).background(Theme.sand).appLayout()
    }
}
