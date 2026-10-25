import SwiftUI

struct ReportView: View {
    @EnvironmentObject var obd: OBDService
    @EnvironmentObject var catalog: CatalogStore
    @Environment(\.dismiss) var dismiss
    @State private var image: Image?
    @State private var pdfURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ReportCard(scan: obd.lastScan, codes: obd.codes, readiness: obd.readiness, catalog: catalog.catalog)
                    if let u = pdfURL {
                        ShareLink(item: u) { Label(L("شارك التقرير PDF", "Share PDF report"), systemImage: "doc.richtext").frame(maxWidth: .infinity).frame(height: 50) }
                            .buttonStyle(.borderedProminent).tint(Theme.terra)
                    }
                    if let img = image {
                        ShareLink(item: img, preview: SharePreview(L("تقرير شخّصها", "Shakhsaha report"), image: img)) {
                            Label(L("شارك كصورة", "Share as image"), systemImage: "photo").frame(maxWidth: .infinity).frame(height: 46)
                        }.buttonStyle(.bordered).tint(Theme.terra)
                    }
                    Text(L("التقرير يوضح حالة كمبيوتر السيارة وقت الفحص فقط، وما يغني عن فحص الوكالة أو ورشة موثوقة قبل الشراء. انتبه: لو الأكواد ممسوحة قريب، الجاهزية بتطلع غير مكتملة.",
                           "This report reflects the car computer at scan time only and doesn't replace a dealer/trusted workshop inspection. If codes were recently cleared, readiness shows incomplete."))
                        .font(.caption).foregroundStyle(Theme.ink.opacity(0.6))
                }.padding(16)
            }
            .background(Theme.sand.ignoresSafeArea())
            .navigationTitle(L("تقرير قبل الشراء", "Pre-purchase report")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("إغلاق", "Close")) { dismiss() } } }
            .task { render() }
        }
    }

    @MainActor func render() {
        let card = ReportCard(scan: obd.lastScan, codes: obd.codes, readiness: obd.readiness, catalog: catalog.catalog)
            .frame(width: 390).padding(16).background(Theme.sand).appLayout()
        let r = ImageRenderer(content: card); r.scale = 3
        if let ui = r.uiImage { image = Image(uiImage: ui) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(L("تقرير-شخصها", "shakhsaha-report") + ".pdf")
        r.render { size, ctx in
            var box = CGRect(origin: .zero, size: size)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil); ctx(pdf); pdf.endPDFPage(); pdf.closePDF()
        }
        pdfURL = url
    }
}

struct ReportCard: View {
    let scan: ScanResult?
    let codes: [FoundCode]
    let readiness: ELMParser.Readiness?
    let catalog: RemoteCatalog
    var total: (Int, Int) {
        codes.reduce((0, 0)) { a, c in let r = CatalogStore.cost(for: c.info, in: catalog); return (a.0 + r.min, a.1 + r.max) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image("Report").resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading) {
                    Text(L("تقرير فحص سيارة", "Vehicle scan report")).font(.title3.bold())
                    Text((scan?.date ?? Date()).formatted(date: .abbreviated, time: .shortened)).font(.caption)
                }
                Spacer()
                ScoreRing(score: scan?.score).scaleEffect(0.75).frame(width: 80, height: 80)
            }
            if let v = scan?.vin {
                row(L("رقم الهيكل", "VIN"), v)
                row(L("الشركة / السنة", "Make / year"), [VINDecoder.make(v), VINDecoder.year(v).map(String.init)].compactMap { $0 }.joined(separator: " · "))
            }
            row(L("لمبة المكينة", "Check engine"), (scan?.milOn ?? false) ? L("شغّالة", "ON") : L("مطفية", "Off"))
            row(L("الجاهزية", "Readiness"), scan.map { L("\($0.monitorsTotal - $0.monitorsIncomplete)/\($0.monitorsTotal) مكتمل", "\($0.monitorsTotal - $0.monitorsIncomplete)/\($0.monitorsTotal) complete") } ?? "—")
            if let v = scan?.voltage { row(L("البطارية", "Battery"), String(format: "%.1f V", v)) }
            Divider()
            Text(L("الأعطال (\(codes.count))", "Faults (\(codes.count))")).font(.headline)
            if codes.isEmpty { Text(L("ما فيه أعطال مسجّلة ✓", "No fault codes ✓")).foregroundStyle(Theme.green) }
            ForEach(codes) { c in
                HStack(alignment: .top) {
                    Text(c.code).font(.caption.monospaced().bold()).foregroundStyle(Theme.terra)
                    Text("\(c.info.title) · \(c.kindTitle)").font(.caption)
                }
            }
            if !codes.isEmpty { row(L("تكلفة تقريبية", "Est. cost"), L("\(total.0) - \(total.1) ريال", "\(total.0)–\(total.1) SAR")) }
            Text(L("صادر من تطبيق شخّصها · قراءة فقط · تقديري", "Generated by Shakhsaha · read-only · estimate")).font(.caption2).foregroundStyle(Theme.ink.opacity(0.5))
        }
        .foregroundStyle(Theme.ink).padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.6)); Spacer(); Text(v).font(.subheadline.bold()) }
    }
}
