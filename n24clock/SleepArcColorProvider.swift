import SwiftUI

final class SleepArcColorProvider {
    static func color(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.1, green: 0.2, blue: 0.35)
        default:
            return Color(red: 0.26, green: 0.54, blue: 0.88)
        }
    }
}
