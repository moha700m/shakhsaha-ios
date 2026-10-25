import SwiftUI

enum MonitorName {
    static func title(_ id: String) -> String {
        switch id {
        case "misfire": return L("مراقبة التفويت", "Misfire")
        case "fuel": return L("نظام الوقود", "Fuel system")
        case "components": return L("القطع الشاملة", "Components")
        case "catalyst": return L("دبة التلوث", "Catalyst")
        case "heatedCat": return L("سخان دبة التلوث", "Heated catalyst")
        case "evap": return L("أبخرة البنزين EVAP", "EVAP")
        case "secondaryAir": return L("الهواء الثانوي", "Secondary air")
        case "acRefrigerant": return L("فريون المكيف", "A/C refrigerant")
        case "o2": return L("حساسات الأكسجين", "O2 sensors")
        case "o2Heater": return L("سخان حساسات الأكسجين", "O2 heater")
        case "egr": return L("نظام EGR", "EGR")
        case "nmhc": return L("محفز NMHC", "NMHC catalyst")
        case "nox": return L("معالج NOx", "NOx aftertreatment")
        case "boost": return L("ضغط التيربو", "Boost pressure")
        case "egs": return L("حساس العادم", "Exhaust gas sensor")
        case "pm": return L("فلتر الجزيئات DPF", "PM filter")
        default: return id
        }
    }
}

struct ReadinessView: View {
    @EnvironmentObject var obd: OBDService
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image("Engine").resizable().scaledToFill().frame(height: 170).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 22))
                if let r = obd.readiness {
                    let ready = !r.milOn && r.incomplete <= 1
                    HStack {
                        Image(systemName: ready ? "checkmark.seal.fill" : "exclamationmark.triangle.fill").font(.largeTitle)
                            .foregroundStyle(ready ? Theme.green : Theme.warn)
                        VStack(alignment: .leading) {
                            Text(ready ? L("غالباً جاهزة للفحص الدوري", "Likely ready for inspection") : L("مو جاهزة للفحص الدوري لسه", "Not ready for inspection yet")).font(.headline)
                            Text(L("لمبة المكينة: \(r.milOn ? "شغّالة" : "مطفية") · أكواد: \(r.dtcCount)", "Check engine: \(r.milOn ? "ON" : "off") · codes: \(r.dtcCount)")).font(.caption)
                        }
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading).softCard(18)
                    VStack(spacing: 0) {
                        ForEach(r.monitors, id: \.id) { m in
                            HStack {
                                Text(MonitorName.title(m.id)).font(.subheadline)
                                Spacer()
                                Label(m.complete ? L("مكتمل", "Complete") : L("غير مكتمل", "Incomplete"), systemImage: m.complete ? "checkmark.circle.fill" : "clock")
                                    .font(.caption.bold()).foregroundStyle(m.complete ? Theme.green : Theme.terra)
                            }.padding(.vertical, 10)
                            Divider()
                        }
                    }.padding(.horizontal, 14).softCard(18)
                    if !ready {
                        Text(L("نصيحة: امشِ ٣٠-٤٠ دقيقة (طريق سريع + زحمة)، ولا تمسح الأكواد قبل الفحص، وصلّح أي عطل يشغّل اللمبة.",
                               "Tip: drive 30–40 minutes mixed highway/city, don't clear codes before inspection, and fix anything lighting the MIL."))
                            .font(.footnote).padding(14).softCard(18)
                    }
                } else {
                    Text(L("سوّ فحص كامل من الرئيسية عشان نعرف الجاهزية.", "Run a full scan from Home to check readiness.")).padding().softCard()
                }
                DisclaimerBanner()
            }.padding(16).foregroundStyle(Theme.ink)
        }
        .background(Theme.sand.ignoresSafeArea())
        .navigationTitle(L("جاهزية الفحص الدوري", "Inspection readiness"))
    }
}
