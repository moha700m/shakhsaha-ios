import SwiftUI
import PhotosUI
import Vision

struct WarningLight: Identifiable, Hashable {
    let id: String, ar: String, en: String, color: String, icon: String, sev: Severity, adviceAr: String, adviceEn: String
    var name: String { L(ar, en) }
    var advice: String { L(adviceAr, adviceEn) }
}

enum WarningLights {
    static let all: [WarningLight] = [
        .init(id: "cel", ar: "لمبة المكينة", en: "Check engine", color: "amber", icon: "engine.combustion", sev: .medium, adviceAr: "ركّب القطعة واقرأ الكود. لو تومض: وقّف، فيه تفويت يحرق دبة التلوث.", adviceEn: "Read codes with the adapter. If flashing, stop: misfire is damaging the catalyst."),
        .init(id: "temp", ar: "حرارة المحرك", en: "Engine temperature", color: "red", icon: "thermometer.high", sev: .high, adviceAr: "وقّف فوراً وطفّ المكينة، لا تفتح غطا الرديتر وهو حار.", adviceEn: "Stop now and switch off. Never open the hot radiator cap."),
        .init(id: "oil", ar: "ضغط الزيت", en: "Oil pressure", color: "red", icon: "oilcan.fill", sev: .high, adviceAr: "وقّف فوراً. شيك مستوى الزيت، المشي بدونه يخرّب المكينة.", adviceEn: "Stop immediately and check oil level."),
        .init(id: "batt", ar: "البطارية/الشحن", en: "Battery / charging", color: "red", icon: "minus.plus.batteryblock.fill", sev: .medium, adviceAr: "الدينمو غالباً ما يشحن. روح ورشة قبل تطفي.", adviceEn: "Alternator likely not charging; get to a workshop."),
        .init(id: "abs", ar: "ABS", en: "ABS", color: "amber", icon: "exclamationmark.circle", sev: .medium, adviceAr: "الفرامل تشتغل بس بدون مانع انزلاق. افحص حساسات الكفرات.", adviceEn: "Brakes work without anti-lock. Check wheel sensors."),
        .init(id: "brake", ar: "الفرامل", en: "Brake system", color: "red", icon: "exclamationmark.brakesignal", sev: .high, adviceAr: "تأكد من الهاندبريك وزيت الفرامل. لو مستمرة لا تسوق.", adviceEn: "Check parking brake and brake fluid."),
        .init(id: "srs", ar: "الإيرباق", en: "Airbag", color: "red", icon: "airbag", sev: .high, adviceAr: "الإيرباق ممكن ما يفتح بالحادث. افحصه بأقرب فرصة.", adviceEn: "Airbags may not deploy; get it checked soon."),
        .init(id: "tpms", ar: "ضغط الكفرات", en: "Tire pressure", color: "amber", icon: "exclamationmark.tirepressure", sev: .medium, adviceAr: "قِس ضغط الكفرات، ممكن بنشر.", adviceEn: "Check tire pressures; possible puncture."),
        .init(id: "fuel", ar: "البنزين قليل", en: "Low fuel", color: "amber", icon: "fuelpump.fill", sev: .low, adviceAr: "عبّ قريب، المشي على الاحتياط يتعب الطرمبة.", adviceEn: "Refuel soon; running low strains the pump."),
        .init(id: "esp", ar: "نظام الثبات", en: "Stability control", color: "amber", icon: "car.side.rear.and.collision.and.car.side.front", sev: .medium, adviceAr: "لو تومض وقت الانزلاق طبيعي. ثابتة؟ افحص.", adviceEn: "Flashing while slipping is normal; steady means fault."),
        .init(id: "glow", ar: "شمعات الديزل", en: "Glow plug (diesel)", color: "amber", icon: "bolt.horizontal", sev: .low, adviceAr: "انتظر لين تنطفي ثم شغّل.", adviceEn: "Wait until it goes off before cranking."),
    ]
}

struct DashAnalysis {
    var odometerCandidates: [Int] = []
    var red = 0, amber = 0, green = 0
    var suggested: [String] {
        var s: [String] = []
        if red > 0 { s += ["temp", "oil", "batt", "brake", "srs"] }
        if amber > 0 { s += ["cel", "abs", "tpms", "esp", "fuel"] }
        return s
    }
}

enum DashAnalyzer {
    static func analyze(_ img: UIImage) async -> DashAnalysis {
        var a = DashAnalysis()
        guard let cg = img.cgImage else { return a }
        // OCR (on-device Vision) for odometer digits
        let req = VNRecognizeTextRequest(); req.recognitionLevel = .accurate; req.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: cg).perform([req])
        let texts = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        for t in texts {
            let digits = t.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: "").filter { $0.isNumber }
            if digits.count >= 4 && digits.count <= 7, let n = Int(digits), n > 500 { a.odometerCandidates.append(n) }
        }
        a.odometerCandidates = Array(Set(a.odometerCandidates)).sorted(by: >)
        // Colour heuristic: count bright saturated red/amber/green blobs on a dark dashboard.
        let w = 96, h = 96
        var px = [UInt8](repeating: 0, count: w * h * 4)
        if let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            for i in stride(from: 0, to: px.count, by: 4) {
                let r = Int(px[i]), g = Int(px[i + 1]), b = Int(px[i + 2])
                let mx = max(r, g, b), mn = min(r, g, b)
                guard mx > 170, mx - mn > 90 else { continue }
                if r == mx && g < 90 { a.red += 1 }
                else if r == mx && g >= 110 && b < 90 { a.amber += 1 }
                else if g == mx && r < 120 { a.green += 1 }
            }
        }
        let minBlob = 6
        if a.red < minBlob { a.red = 0 }
        if a.amber < minBlob { a.amber = 0 }
        return a
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ u: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> C { C(self) }
    final class C: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let p: CameraPicker; init(_ p: CameraPicker) { self.p = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            p.image = info[.originalImage] as? UIImage; p.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { p.dismiss() }
    }
}

struct DashPhotoView: View {
    @EnvironmentObject var cars: VehicleStore
    @State private var image: UIImage?
    @State private var showCam = false
    @State private var item: PhotosPickerItem?
    @State private var analysis: DashAnalysis?
    @State private var picked: Set<String> = []
    @State private var savedOdo: Int?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let i = image {
                    Image(uiImage: i).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Image("Report").resizable().scaledToFill().frame(height: 170).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 20))
                    Text(L("صوّر الطبلون والسويتش شغّال، ونقرأ العداد ونقترح اللمبات اللي ولّعت. أنت تأكّد اللمبة من القائمة.",
                           "Photograph the cluster with ignition on. We read the odometer and suggest lit lights; you confirm from the list.")).font(.subheadline)
                }
                HStack {
                    Button { showCam = true } label: { Label(L("صوّر", "Camera"), systemImage: "camera").frame(maxWidth: .infinity).frame(height: 46) }.buttonStyle(.borderedProminent).tint(Theme.terra)
                    PhotosPicker(selection: $item, matching: .images) { Label(L("من الصور", "Photos"), systemImage: "photo").frame(maxWidth: .infinity).frame(height: 46) }.buttonStyle(.bordered).tint(Theme.terra)
                }
                if let a = analysis {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("العداد", "Odometer")).font(.headline)
                        if a.odometerCandidates.isEmpty { Text(L("ما قدرنا نقرأ العداد، قرّب الصورة.", "Couldn't read odometer; move closer.")).font(.caption) }
                        ForEach(a.odometerCandidates.prefix(3), id: \.self) { n in
                            Button { var c = cars.current; c.odometer = n; cars.current = c; savedOdo = n } label: {
                                HStack { Text("\(n) km").font(.headline.monospacedDigit()); Spacer(); Text(savedOdo == n ? L("انحفظ ✓", "Saved ✓") : L("احفظ للسيارة", "Save to car")) }
                            }
                        }
                        Text(L("ألوان لاحظناها: أحمر \(a.red > 0 ? "نعم" : "لا") · برتقالي \(a.amber > 0 ? "نعم" : "لا")", "Colours seen: red \(a.red > 0 ? "yes" : "no") · amber \(a.amber > 0 ? "yes" : "no")")).font(.caption)
                    }.padding(14).softCard(18)
                }
                Text(L("وش اللمبات اللي شايفها؟", "Which lights do you see?")).font(.headline)
                ForEach(WarningLights.all.sorted { (analysis?.suggested.contains($0.id) ?? false) && !(analysis?.suggested.contains($1.id) ?? false) }) { w in
                    Button { if picked.contains(w.id) { picked.remove(w.id) } else { picked.insert(w.id) } } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: w.icon).font(.title2).frame(width: 36).foregroundStyle(w.color == "red" ? Theme.warn : Color.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack { Text(w.name).font(.subheadline.bold()); if analysis?.suggested.contains(w.id) == true { Text(L("محتمل", "likely")).font(.caption2).foregroundStyle(Theme.terra) } }
                                if picked.contains(w.id) { Text(w.advice).font(.caption); Text(w.sev.title).font(.caption2.bold()).foregroundStyle(w.sev == .high ? Theme.warn : Theme.terra) }
                            }
                            Spacer()
                            Image(systemName: picked.contains(w.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(Theme.terra)
                        }.foregroundStyle(Theme.ink).padding(12).softCard(16)
                    }.buttonStyle(.plain)
                }
                Text(L("القراءة بالكاميرا تقريبية (نص وألوان على الجهاز، بدون نموذج مدرّب)، والتأكيد منك. للأكواد الدقيقة استخدم قطعة OBD.",
                       "Camera reading is approximate (on-device text + colour, no trained model) and you confirm. Use an OBD adapter for exact codes.")).font(.caption2)
            }.padding(16).foregroundStyle(Theme.ink)
        }
        .background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("صوّر طبلونك", "Snap your dashboard"))
        .sheet(isPresented: $showCam) { CameraPicker(image: $image).ignoresSafeArea() }
        .onChange(of: item) { _, new in Task { if let d = try? await new?.loadTransferable(type: Data.self), let u = UIImage(data: d) { image = u } } }
        .onChange(of: image) { _, new in guard let i = new else { return }; Task { let a = await DashAnalyzer.analyze(i); analysis = a; picked.formUnion(a.suggested.prefix(0)) } }
    }
}
