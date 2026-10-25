import SwiftUI

struct ConnectView: View {
    @EnvironmentObject var obd: OBDService
    @EnvironmentObject var catalog: CatalogStore
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image("Adapter").resizable().scaledToFill().frame(height: 200).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 24))
                    step(1, L("ركّب القطعة في منفذ OBD2 تحت الدركسون (يسار تحت).", "Plug the adapter into the OBD2 port under the steering wheel."))
                    step(2, L("شغّل السويتش (أو المكينة) وخل الجوال قريب.", "Turn ignition on and keep the phone close."))
                    step(3, L("اضغط اتصال، وأول مرة بيطلب إذن البلوتوث.", "Tap connect. The first time iOS asks for Bluetooth."))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("القطع اللي تشتغل مع الآيفون", "Adapters that work with iPhone")).font(.headline)
                        Text(L("لازم تكون BLE (بلوتوث 4.0 أو أحدث): OBDLink CX أو MX+، Vgate iCar Pro BLE، vLinker MC-IOS، Veepeak BLE+. القطع الرخيصة «بلوتوث كلاسيك» ما تشتغل على الآيفون.",
                               "Must be BLE (Bluetooth 4.0+): OBDLink CX/MX+, Vgate iCar Pro BLE, vLinker MC-IOS, Veepeak BLE+. Classic Bluetooth clones don't work on iPhone.")).font(.footnote)
                    }.padding(14).softCard(18)
                    if case .failed(let e) = obd.state {
                        Label(e, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.warn).font(.footnote)
                        if e.contains(L("الإعدادات", "permission")) {
                            Button(L("افتح إعدادات الآيفون", "Open iPhone Settings")) { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
                        }
                    }
                    PrimaryButton(title: obd.state == .connecting ? L("يدوّر على القطعة…", "Searching…") : L("اتصال بالقطعة", "Connect adapter")) {
                        Task { await obd.connect(demo: false); if obd.connected { dismiss() } }
                    }.disabled(obd.state == .connecting)
                    SecondaryButton(title: L("جرّب الوضع التجريبي بدون قطعة", "Try demo mode (no adapter)")) {
                        Task { await obd.connect(demo: true); await obd.fullScan(catalog: catalog.catalog); dismiss() }
                    }
                }.padding(18).foregroundStyle(Theme.ink)
            }
            .background(Theme.sand.ignoresSafeArea())
            .navigationTitle(L("الاتصال", "Connect")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("إغلاق", "Close")) { dismiss() } } }
        }
    }
    func step(_ n: Int, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.headline).frame(width: 30, height: 30).background(Theme.terra, in: Circle()).foregroundStyle(.white)
            Text(t).font(.subheadline)
        }
    }
}

struct DTCDetailView: View {
    let code: FoundCode
    @EnvironmentObject var catalog: CatalogStore
    var info: DTCInfo { code.info }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(info.code).font(.system(size: 34, weight: .heavy, design: .monospaced)).foregroundStyle(Theme.terra)
                    Spacer()
                    Text(info.severity.title).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 6)
                        .background((info.severity == .high ? Theme.warn : Theme.terra).opacity(0.15), in: Capsule())
                        .foregroundStyle(info.severity == .high ? Theme.warn : Theme.terra)
                }
                Text(info.title).font(.title3.bold())
                Image(image).resizable().scaledToFill().frame(height: 180).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 22))
                card(L("وش يعني؟", "What it means"), "sparkles", DTCDatabase.explain(info))
                let c = catalog.cost(for: info)
                card(L("التكلفة التقريبية", "Estimated cost"), "banknote", L("من \(c.min) إلى \(c.max) ريال (قطع + شغل). تختلف حسب السيارة والورشة.", "\(c.min)–\(c.max) SAR (parts + labor). Varies by car and workshop."))
                VStack(alignment: .leading, spacing: 10) {
                    Label(L("خطوات الإصلاح", "Repair steps"), systemImage: "wrench.adjustable").font(.headline)
                    ForEach(Array(DTCDatabase.steps(info).enumerated()), id: \.offset) { i, s in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)").font(.caption.bold()).frame(width: 24, height: 24).background(Theme.terra.opacity(0.18), in: Circle())
                            Text(s).font(.subheadline)
                        }
                    }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).softCard(18)
                card(L("وش تقول للميكانيكي", "What to tell the mechanic"), "person.wave.2", DTCDatabase.mechanicScript(info))
                ShareLink(item: shareText) { Label(L("شارك العطل", "Share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).frame(height: 50) }
                    .buttonStyle(.borderedProminent).tint(Theme.terra)
                Link(destination: URL(string: "https://maps.apple.com/?q=" + (L("ورشة سيارات", "car repair").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))!) {
                    Label(L("أقرب ورشة", "Nearest workshop"), systemImage: "mappin.and.ellipse").frame(maxWidth: .infinity).frame(height: 46)
                }.buttonStyle(.bordered).tint(Theme.terra)
                DisclaimerBanner()
            }.padding(16).foregroundStyle(Theme.ink)
        }
        .background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("تفاصيل العطل", "Fault detail")).navigationBarTitleDisplayMode(.inline)
    }
    var image: String {
        switch info.system { case "cooling": return "Heat"; case "electrical": return "Maint"; default: return "Engine" }
    }
    var shareText: String { "\(info.code) — \(info.title)\n\(DTCDatabase.explain(info))\n\(L("عبر تطبيق شخّصها", "via Shakhsaha"))" }
    func card(_ t: String, _ icon: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Label(t, systemImage: icon).font(.headline); Text(body).font(.subheadline) }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).softCard(18)
    }
}
