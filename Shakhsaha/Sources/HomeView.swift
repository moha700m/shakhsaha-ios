import SwiftUI

struct HomeView: View {
    @EnvironmentObject var obd: OBDService
    @EnvironmentObject var catalog: CatalogStore
    @State private var showConnect = false
    @State private var showReport = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.sand.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        hero
                        if obd.heatAlert { HeatBanner() }
                        connectCard
                        if obd.connected {
                            PrimaryButton(title: obd.scanning ? L("جاري الفحص…", "Scanning…") : L("افحص السيارة كاملة", "Run full scan")) {
                                Task { await obd.fullScan(catalog: catalog.catalog) }
                            }.disabled(obd.scanning)
                            if obd.scanning { ProgressView(value: obd.scanProgress).tint(Theme.terra) }
                        }
                        if obd.lastScan != nil { resultsSection }
                        tiles
                        if let tip = catalog.tips.first { tipCard(tip) }
                        DisclaimerBanner()
                    }.padding(16)
                }
            }
            .navigationTitle(L("شخّصها", "Shakhsaha"))
            .sheet(isPresented: $showConnect) { ConnectView() }
            .sheet(isPresented: $showReport) { ReportView() }
        }
    }

    var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("Hero").resizable().scaledToFill().frame(height: 230).clipped()
            LinearGradient(colors: [.clear, Theme.sand.opacity(0.9)], startPoint: .center, endPoint: .bottom)
            HStack {
                ScoreRing(score: obd.lastScan?.score)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let v = obd.vin ?? obd.lastScan?.vin {
                        Text([VINDecoder.make(v), VINDecoder.year(v).map(String.init)].compactMap { $0 }.joined(separator: " · ")).font(.headline)
                        Text(v).font(.caption.monospaced()).foregroundStyle(Theme.ink.opacity(0.6))
                    } else {
                        Text(L("سيارتي", "My car")).font(.headline)
                    }
                }.foregroundStyle(Theme.ink)
            }.padding(16)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    var connectCard: some View {
        HStack(spacing: 12) {
            Image("Adapter").resizable().scaledToFill().frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 3) {
                switch obd.state {
                case .idle: Text(L("مو متصل", "Not connected")).font(.headline)
                    Text(L("ركّب القطعة وشغّل السويتش", "Plug in adapter, ignition on")).font(.caption)
                case .connecting: Text(L("جاري الاتصال…", "Connecting…")).font(.headline)
                case .connected(let n): Text(L("متصل", "Connected")).font(.headline).foregroundStyle(Theme.green)
                    Text(obd.isDemo ? L("وضع تجريبي (بدون قطعة)", "Demo mode (no adapter)") : n).font(.caption)
                case .failed(let e): Text(L("ما قدرنا نتصل", "Couldn't connect")).font(.headline).foregroundStyle(Theme.warn)
                    Text(e).font(.caption)
                }
            }.foregroundStyle(Theme.ink)
            Spacer()
            Button(obd.connected ? L("فصل", "Disconnect") : L("اتصال", "Connect")) {
                if obd.connected { obd.disconnect() } else { showConnect = true }
            }.buttonStyle(.borderedProminent).tint(Theme.terra)
        }.padding(14).softCard()
    }

    var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("الأعطال", "Faults")).font(.title3.bold())
                Spacer()
                if !obd.codes.isEmpty && obd.connected {
                    ClearCodesButton()
                }
            }
            if obd.codes.isEmpty {
                HStack { Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.green); Text(L("ما فيه أعطال مسجّلة، سيارتك تمام", "No fault codes, looking good")) }
                    .padding().frame(maxWidth: .infinity, alignment: .leading).softCard()
            }
            ForEach(obd.codes) { c in
                NavigationLink { DTCDetailView(code: c) } label: { DTCRow(code: c) }.buttonStyle(.plain)
            }
            if let f = obd.freezeFrameCode {
                Label(L("لقطة التجميد: العطل \(f) هو اللي شغّل لمبة المكينة", "Freeze frame: \(f) triggered the check-engine light"), systemImage: "camera.metering.spot")
                    .font(.footnote).padding(12).frame(maxWidth: .infinity, alignment: .leading).softCard(16)
            }
        }.foregroundStyle(Theme.ink)
    }

    var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            NavigationLink { ReadinessView() } label: { Tile(img: "Engine", title: L("جاهزية الفحص الدوري", "Inspection readiness"),
                sub: obd.readiness.map { $0.incomplete == 0 && !$0.milOn ? L("جاهزة ✓", "Ready ✓") : L("\($0.incomplete) غير مكتمل", "\($0.incomplete) incomplete") } ?? L("افحص أول", "Scan first")) }
            Button { showReport = true } label: { Tile(img: "Report", title: L("تقرير قبل الشراء", "Pre-purchase report"), sub: L("شاركه مع البايع", "Share with seller")) }
            NavigationLink { LiveView() } label: { Tile(img: "Heat", title: L("الحرارة والبطارية", "Heat & battery"),
                sub: obd.live.voltage > 0 ? String(format: "%.1fV", obd.live.voltage) : "—") }
            NavigationLink { MaintenanceView() } label: { Tile(img: "Maint", title: L("تذكيرات الصيانة", "Service reminders"), sub: L("زيت، بطارية، مكيف", "Oil, battery, A/C")) }
        }.buttonStyle(.plain)
    }

    func tipCard(_ t: String) -> some View {
        HStack(alignment: .top) { Image(systemName: "lightbulb.fill").foregroundStyle(Theme.terra); Text(t).font(.footnote) }
            .foregroundStyle(Theme.ink).padding(14).frame(maxWidth: .infinity, alignment: .leading).softCard(18)
    }
}

struct ClearCodesButton: View {
    @EnvironmentObject var obd: OBDService
    @EnvironmentObject var catalog: CatalogStore
    @State private var ask = false
    var body: some View {
        Button(L("مسح الأكواد", "Clear codes")) { ask = true }.font(.subheadline.bold()).foregroundStyle(Theme.warn)
            .confirmationDialog(L("متأكد؟", "Are you sure?"), isPresented: $ask, titleVisibility: .visible) {
                Button(L("امسح الأكواد", "Clear codes"), role: .destructive) { Task { await obd.clearCodes(catalog: catalog.catalog) } }
            } message: {
                Text(L("المسح يطفي اللمبة بس ما يصلح العطل، ويصفّر جاهزية الفحص الدوري. السيارة لازم تكون واقفة والمكينة مطفية والسويتش شغّال.",
                       "Clearing turns the light off but doesn't fix the fault, and resets inspection readiness. Vehicle must be parked, engine off, ignition on."))
            }
    }
}

struct Tile: View {
    let img: String, title: String, sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(img).resizable().scaledToFill().frame(height: 90).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 14))
            Text(title).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.8)
            Text(sub).font(.caption).foregroundStyle(Theme.ink.opacity(0.6))
        }.foregroundStyle(Theme.ink).padding(10).softCard(20)
    }
}

struct ScoreRing: View {
    let score: Int?
    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.85))
            Circle().stroke(Theme.ink.opacity(0.08), lineWidth: 9)
            Circle().trim(from: 0, to: CGFloat(score ?? 0) / 100).stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(score.map { "\($0)" } ?? "—").font(.system(size: 30, weight: .heavy, design: .rounded))
                Text(L("صحة السيارة", "Health")).font(.caption2)
            }.foregroundStyle(Theme.ink)
        }.frame(width: 104, height: 104)
    }
    var color: Color { guard let s = score else { return .gray }; return s >= 80 ? Theme.green : s >= 55 ? Theme.terra : Theme.warn }
}

struct DTCRow: View {
    let code: FoundCode
    var body: some View {
        HStack(spacing: 12) {
            Text(code.code).font(.system(.headline, design: .monospaced)).padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.terra.opacity(0.15), in: Capsule()).foregroundStyle(Theme.terra)
            VStack(alignment: .leading, spacing: 2) {
                Text(code.info.title).font(.subheadline.bold()).lineLimit(2)
                Text("\(code.kindTitle) · \(code.info.severity.title)").font(.caption).foregroundStyle(code.info.severity == .high ? Theme.warn : Theme.ink.opacity(0.6))
            }
            Spacer()
            Image(systemName: "chevron.forward").foregroundStyle(Theme.ink.opacity(0.3))
        }.foregroundStyle(Theme.ink).padding(12).softCard(18)
    }
}
