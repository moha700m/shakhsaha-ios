import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject var maint: MaintenanceStore
    @State private var adding = false
    @State private var newTitle = ""
    @State private var newDate = Date().addingTimeInterval(86400 * 30)
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Image("Maint").resizable().scaledToFill().frame(height: 150).clipped().listRowInsets(EdgeInsets())
                }
                Section(L("القادم", "Upcoming")) {
                    ForEach(maint.items.sorted { $0.due < $1.due }) { i in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(i.title).font(.subheadline.bold())
                                Text(i.due, style: .date).font(.caption).foregroundStyle(i.due < Date() ? Theme.warn : Theme.ink.opacity(0.6))
                            }
                            Spacer()
                            Button(L("تم", "Done")) { maint.markDone(i) }.buttonStyle(.bordered).tint(Theme.green)
                        }
                        .swipeActions { Button(L("حذف", "Delete"), role: .destructive) { maint.remove(i) } }
                    }
                }
                Section(L("إضافة تذكير", "Add reminder")) {
                    TextField(L("مثلاً: تجديد الاستمارة", "e.g. registration renewal"), text: $newTitle)
                    DatePicker(L("الموعد", "Date"), selection: $newDate, displayedComponents: .date)
                    Button(L("أضف", "Add")) {
                        guard !newTitle.isEmpty else { return }
                        maint.add(MaintItem(kind: "custom", title: newTitle, due: newDate, everyMonths: 12)); newTitle = ""
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Theme.sand.ignoresSafeArea())
            .navigationTitle(L("الصيانة", "Service"))
            .onAppear { Notifier.request(); maint.scheduleAll() }
        }
    }
}
