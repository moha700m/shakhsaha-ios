import SwiftUI

struct LiveView: View {
    @EnvironmentObject var obd: OBDService
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if !obd.connected {
                        Label(L("اتصل بالقطعة أول من الرئيسية", "Connect the adapter from Home first"), systemImage: "antenna.radiowaves.left.and.right")
                            .padding().frame(maxWidth: .infinity).softCard()
                    }
                    if obd.heatAlert { HeatBanner() }
                    Gauge2(title: L("الدورات", "RPM"), value: obd.live.rpm, max: 7000, unit: "rpm", fmt: "%.0f", warn: 6000).frame(height: 200)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        Gauge2(title: L("السرعة", "Speed"), value: obd.live.speed, max: 220, unit: L("كم/س", "km/h"), fmt: "%.0f", warn: 999)
                        Gauge2(title: L("حرارة الماء", "Coolant"), value: obd.live.coolant, max: 130, unit: "°C", fmt: "%.0f", warn: obd.heatLimit)
                        Gauge2(title: L("البطارية", "Battery"), value: obd.live.voltage, max: 16, unit: "V", fmt: "%.1f", warn: 15.2, low: 12.2)
                        Gauge2(title: L("دعسة البنزين", "Throttle"), value: obd.live.throttle, max: 100, unit: "%", fmt: "%.0f", warn: 999)
                        Gauge2(title: L("حمل المحرك", "Engine load"), value: obd.live.load, max: 100, unit: "%", fmt: "%.0f", warn: 90)
                        Gauge2(title: L("حرارة الهواء الداخل", "Intake air"), value: obd.live.intake, max: 90, unit: "°C", fmt: "%.0f", warn: 70)
                    }
                    DisclaimerBanner()
                }.padding(16)
            }
            .background(Theme.sand.ignoresSafeArea())
            .navigationTitle(L("القراءات المباشرة", "Live data"))
            .onAppear { obd.startLive() }
            .onDisappear { obd.stopLive() }
        }
    }
}

struct Gauge2: View {
    let title: String; let value: Double; let max: Double; let unit: String; let fmt: String; let warn: Double
    var low: Double = -1
    var bad: Bool { value >= warn || (low > 0 && value > 0 && value < low) }
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().trim(from: 0.15, to: 0.85).stroke(Theme.ink.opacity(0.08), style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(90))
                Circle().trim(from: 0.15, to: 0.15 + 0.7 * min(1, Swift.max(0, value / max)))
                    .stroke(bad ? Theme.warn : Theme.terra, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(90))
                    .animation(.easeOut(duration: 0.4), value: value)
                VStack(spacing: 0) {
                    Text(String(format: fmt, value)).font(.system(size: 28, weight: .heavy, design: .rounded)).monospacedDigit()
                    Text(unit).font(.caption2).foregroundStyle(Theme.ink.opacity(0.6))
                }
            }.padding(8)
            Text(title).font(.caption.bold())
        }.foregroundStyle(Theme.ink).padding(10).frame(minHeight: 150).softCard(22)
    }
}
