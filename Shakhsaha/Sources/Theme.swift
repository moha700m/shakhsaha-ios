import SwiftUI

enum Theme {
    static let sand = Color(red: 0.961, green: 0.929, blue: 0.878)      // #F5EDE0
    static let ink = Color(red: 0.165, green: 0.129, blue: 0.094)        // #2A2118
    static let green = Color(red: 0.184, green: 0.420, blue: 0.310)
    static let terra = Color(red: 0.769, green: 0.420, blue: 0.290)      // #C46B4A
    static let warn = Color(red: 0.769, green: 0.361, blue: 0.243)       // #C45C3E
    static let softCard = Color.white.opacity(0.88)
}

struct SoftCard: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            content
                .background(Theme.softCard, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
                .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 6)
        }
    }
}

extension View {
    func softCard(_ r: CGFloat = 20) -> some View { modifier(SoftCard(radius: r)) }
}

struct PrimaryButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Theme.terra, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct DisclaimerBanner: View {
    var body: some View {
        Text(L("قراءة فقط · التشخيص والأسعار تقريبية وما تغني عن الميكانيكي",
                 "Read-only · diagnosis and prices are estimates, not a replacement for a mechanic"))
            .font(.caption2)
            .foregroundStyle(Theme.ink.opacity(0.45))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

struct DesertBackground: View {
    var body: some View {
        GeometryReader { g in
            Image("Hero").resizable().scaledToFill()
                .frame(width: g.size.width, height: g.size.height).clipped()
                .overlay(LinearGradient(colors: [
                    Theme.sand.opacity(0.55),
                    Theme.sand.opacity(0.88),
                    Theme.sand.opacity(0.96)
                ], startPoint: .top, endPoint: .bottom))
        }.ignoresSafeArea()
    }
}
