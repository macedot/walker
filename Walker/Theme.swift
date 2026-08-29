import SwiftUI

extension Color {
    static let walkerBg = Color(red: 0.04, green: 0.05, blue: 0.06)
    static let walkerPanel = Color(red: 0.10, green: 0.11, blue: 0.13)
    static let walkerPanelStroke = Color.white.opacity(0.08)
    static let bloodRed = Color(red: 0.82, green: 0.10, blue: 0.10)
    static let toxicGreen = Color(red: 0.45, green: 0.85, blue: 0.35)
    static let amberWarn = Color(red: 0.95, green: 0.72, blue: 0.20)
}

extension ShapeStyle where Self == Color {
    static var walkerBg: Color { Color(red: 0.04, green: 0.05, blue: 0.06) }
    static var walkerPanel: Color { Color(red: 0.10, green: 0.11, blue: 0.13) }
    static var walkerPanelStroke: Color { Color.white.opacity(0.08) }
    static var bloodRed: Color { Color(red: 0.82, green: 0.10, blue: 0.10) }
    static var toxicGreen: Color { Color(red: 0.45, green: 0.85, blue: 0.35) }
    static var amberWarn: Color { Color(red: 0.95, green: 0.72, blue: 0.20) }
}

extension View {
    func panel() -> some View {
        padding(12)
            .background(Color.walkerPanel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.walkerPanelStroke)
            )
    }
}

enum Format {
    static func distance(_ meters: Double) -> String {
        String(format: "%.2f km", meters / 1000)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    static func pace(meters: Double, seconds: TimeInterval) -> String {
        guard meters > 20, seconds > 5 else { return "--:--" }
        let secPerKm = seconds / (meters / 1000)
        return String(format: "%d:%02d /km", Int(secPerKm) / 60, Int(secPerKm) % 60)
    }
}
