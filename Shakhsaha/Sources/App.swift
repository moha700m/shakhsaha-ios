import SwiftUI

@main
struct ShakhsahaApp: App {
    @StateObject private var obd = OBDService()
    @StateObject private var catalog = CatalogStore()
    @StateObject private var maint = MaintenanceStore()
    @AppStorage("shakhsaha.lang") private var langRaw = "ar"
    @AppStorage("shakhsaha.agreed") private var agreed = false

    var body: some Scene {
        WindowGroup {
            Group {
                if agreed { RootView() } else { OnboardingView(agreed: $agreed) }
            }
            .environmentObject(obd).environmentObject(catalog).environmentObject(maint)
            .appLayout(AppLang(rawValue: langRaw) ?? .ar)
            .id(langRaw)
            .tint(Theme.terra)
            .preferredColorScheme(.light)
            .task {
                await catalog.refresh()
                obd.heatLimit = catalog.catalog.heatLimitC ?? 105
                if ProcessInfo.processInfo.environment["SHOT"] != nil { agreed = true; await obd.connect(demo: true); await obd.fullScan(catalog: catalog.catalog) }
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var obd: OBDService
    var body: some View {
        ZStack {
            TabView {
                HomeView().tabItem { Label(L("الرئيسية", "Home"), systemImage: "house.fill") }
                LiveView().tabItem { Label(L("مباشر", "Live"), systemImage: "gauge.with.dots.needle.67percent") }
                MaintenanceView().tabItem { Label(L("الصيانة", "Service"), systemImage: "wrench.and.screwdriver.fill") }
                SettingsView().tabItem { Label(L("الإعدادات", "Settings"), systemImage: "gearshape.fill") }
            }
            if obd.drivingLocked { DrivingLockView() }
        }
    }
}

struct OnboardingView: View {
    @Binding var agreed: Bool
    var body: some View {
        ZStack {
            DesertBackground()
            VStack(spacing: 18) {
                Spacer()
                Image("Adapter").resizable().scaledToFill().frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                Text(L("شخّصها", "Shakhsaha")).font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                Text(L("ركّب قطعة OBD2 تحت الدركسون، وخلّنا نقرأ سيارتك ونشرح لك أعطالها بالسعودي مع سعر تقريبي بالريال.",
                       "Plug an OBD2 adapter under the dashboard and we'll read your car and explain faults with SAR estimates."))
                    .multilineTextAlignment(.center).foregroundStyle(Theme.ink.opacity(0.75))
                VStack(alignment: .leading, spacing: 8) {
                    Label(L("التطبيق يقرأ فقط، ما يبرمج ولا يغيّر شي في كمبيوتر السيارة", "Read-only: never programs or changes your car's computer"), systemImage: "lock.shield")
                    Label(L("الأسعار والشرح تقريبية، القرار الأخير للميكانيكي", "Prices and explanations are estimates"), systemImage: "info.circle")
                    Label(L("لا تستخدم التطبيق وأنت تسوق", "Never use the app while driving"), systemImage: "car.side")
                    Label(L("بياناتك تبقى في جوالك", "Your data stays on your phone"), systemImage: "hand.raised")
                }.font(.footnote).foregroundStyle(Theme.ink).padding().softCard()
                PrimaryButton(title: L("موافق، يلا نبدأ", "I agree, let's start")) { Notifier.request(); agreed = true }
                Spacer(minLength: 10)
            }.padding(24)
        }
    }
}

struct DrivingLockView: View {
    @EnvironmentObject var obd: OBDService
    var body: some View {
        ZStack {
            Theme.sand.opacity(0.97).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "car.side.fill").font(.system(size: 60)).foregroundStyle(Theme.terra)
                Text(L("ركّز على الطريق", "Eyes on the road")).font(.title.bold()).foregroundStyle(Theme.ink)
                Text(L("السيارة ماشية فوق ١٠ كم/س، قفلنا الشاشة عشان سلامتك.", "Vehicle is above 10 km/h. Screen locked for your safety."))
                    .multilineTextAlignment(.center).foregroundStyle(Theme.ink.opacity(0.7))
                if obd.heatAlert { HeatBanner() }
                SecondaryButton(title: L("أنا راكب مو سايق", "I'm a passenger")) { obd.passengerMode = true }
            }.padding(30)
        }
    }
}

struct HeatBanner: View {
    @EnvironmentObject var obd: OBDService
    var body: some View {
        HStack(spacing: 12) {
            Image("Heat").resizable().scaledToFill().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(L("حرارة المحرك \(Int(obd.live.coolant))°", "Engine \(Int(obd.live.coolant))°")).font(.headline).foregroundStyle(.white)
                Text(L("وقّف بمكان آمن وطفّ المكيف", "Pull over and switch off A/C")).font(.caption).foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }.padding(12).background(Theme.warn, in: RoundedRectangle(cornerRadius: 18))
    }
}
