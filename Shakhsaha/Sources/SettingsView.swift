import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var obd: OBDService
    @EnvironmentObject var catalog: CatalogStore
    @AppStorage("shakhsaha.lang") private var langRaw = "ar"
    var body: some View {
        NavigationStack {
            Form {
                Section(L("اللغة", "Language")) {
                    Picker(L("اللغة", "Language"), selection: Binding(get: { langRaw }, set: { v in L10n.setLang(AppLang(rawValue: v) ?? .ar); langRaw = v })) {
                        ForEach(AppLang.allCases) { Text($0.title).tag($0.rawValue) }
                    }.pickerStyle(.segmented)
                }
                Section(L("السلامة", "Safety")) {
                    Toggle(L("أنا راكب (فك قفل القيادة)", "Passenger mode (unlock while moving)"), isOn: $obd.passengerMode)
                    Text(L("الشاشة تنقفل تلقائياً إذا السرعة فوق ١٠ كم/س. لا تستخدم الجوال وأنت تسوق.", "The screen locks above 10 km/h. Never use the phone while driving.")).font(.caption)
                }
                Section(L("المحتوى", "Content")) {
                    LabeledContent(L("نسخة الأسعار", "Price catalog"), value: "v\(catalog.catalog.version)")
                    Button(L("تحديث الأسعار", "Refresh prices")) { Task { await catalog.refresh() } }
                }
                Section(L("عن التطبيق", "About")) {
                    Text(L("شخّصها يقرأ بيانات OBD-II القياسية فقط (قراءة الأعطال والقراءات المباشرة)، والأمر الوحيد اللي يرسله للسيارة غير القراءة هو مسح الأكواد إذا طلبته أنت. ما يبرمج ولا يعدّل الكمبيوتر.",
                           "Shakhsaha only reads standard OBD-II data. The only non-read command is clearing codes when you ask. It never programs or modifies ECUs.")).font(.footnote)
                    Text(L("ما نجمع أي بيانات. كل شي في جوالك.", "We collect no data. Everything stays on your phone.")).font(.footnote)
                    Link(L("سياسة الخصوصية", "Privacy policy"), destination: URL(string: "https://moha700m.github.io/shakhsaha-ios/privacy.html")!)
                    Link(L("إعدادات الآيفون (البلوتوث والتنبيهات)", "iPhone Settings"), destination: URL(string: UIApplication.openSettingsURLString)!)
                }
            }
            .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
            .navigationTitle(L("الإعدادات", "Settings"))
        }
    }
}
