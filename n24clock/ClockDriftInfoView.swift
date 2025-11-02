import SwiftUI

struct ClockDriftInfoView: View {
    let state: BiologicalClock.State
    let date: Date

    private var info: DriftInfo {
        ClockDriftCalculator().info(for: state, at: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(info.destinationDescription)
                .font(.title3)
            Text("与本地时间相差 \(info.differenceText)")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DriftInfo {
    let differenceText: String
    let cityName: String
    let utcDescription: String

    var destinationDescription: String {
        "你今天漂移到了\(cityName) \(utcDescription)"
    }
}

private struct ClockDriftCalculator {
    func info(for state: BiologicalClock.State, at date: Date) -> DriftInfo {
        let differences = differenceDetails(state: state, date: date)
        let destination = destinationDetails(roundedShift: differences.roundedShiftHours, date: date)
        return DriftInfo(differenceText: differences.formattedDifference,
                         cityName: destination.city,
                         utcDescription: destination.utc)
    }

    private func differenceDetails(state: BiologicalClock.State, date: Date) -> (seconds: Double, formattedDifference: String, roundedShiftHours: Int) {
        let differenceSeconds = normalizedDifferenceSeconds(state: state, date: date)
        let formatted = formatDifference(seconds: differenceSeconds)
        let roundedShift = roundedShiftHours(for: differenceSeconds)
        return (differenceSeconds, formatted, roundedShift)
    }

    private func normalizedDifferenceSeconds(state: BiologicalClock.State, date: Date) -> Double {
        let secondsPerDay = Self.secondsPerDay
        let bioSeconds = state.progress * secondsPerDay

        let calendar = Calendar.current
        let components = calendar.dateComponents(in: TimeZone.current, from: date)
        let localSeconds = Double(components.hour ?? 0) * 3600
            + Double(components.minute ?? 0) * 60
            + Double(components.second ?? 0)

        let rawDifference = bioSeconds - localSeconds
        return wrapToHalfDay(rawDifference)
    }

    private func wrapToHalfDay(_ value: Double) -> Double {
        let daySeconds = Self.secondsPerDay
        var wrapped = value.truncatingRemainder(dividingBy: daySeconds)

        let halfDay = daySeconds / 2
        if wrapped > halfDay {
            wrapped -= daySeconds
        } else if wrapped < -halfDay {
            wrapped += daySeconds
        }

        return wrapped
    }

    private func formatDifference(seconds: Double) -> String {
        let totalMinutes = Int((seconds / 60).rounded(.towardZero))
        let hours = totalMinutes / 60
        let minutes = abs(totalMinutes % 60)

        return String(format: "%+dh%02dmin", hours, minutes)
    }

    private func roundedShiftHours(for seconds: Double) -> Int {
        let hours = (seconds / 3600).rounded()
        let clamped = max(-12, min(12, Int(hours)))
        return clamped
    }

    private func destinationDetails(roundedShift: Int, date: Date) -> (city: String, utc: String) {
        let localOffsetSeconds = TimeZone.current.secondsFromGMT(for: date)
        let localOffsetHours = Double(localOffsetSeconds) / 3600
        let targetOffsetHours = localOffsetHours + Double(roundedShift)
        let roundedOffset = Int(targetOffsetHours.rounded())
        let clampedOffset = max(-12, min(12, roundedOffset))

        let city = TimeZoneCatalog.city(for: clampedOffset)
        let utcDescription = "UTC" + formatUTCOffset(hours: clampedOffset)
        return (city, utcDescription)
    }

    private func formatUTCOffset(hours: Int) -> String {
        if hours > 0 {
            return "+\(hours)"
        } else if hours < 0 {
            return "\(hours)"
        } else {
            return "+0"
        }
    }
}

private enum TimeZoneCatalog {
    static func city(for offset: Int) -> String {
        catalog[offset] ?? "未知城市"
    }

    private static let catalog: [Int: String] = [
        -12: "贝克岛",
        -11: "帕果帕果",
        -10: "檀香山",
        -9: "安克雷奇",
        -8: "洛杉矶",
        -7: "丹佛",
        -6: "芝加哥",
        -5: "纽约",
        -4: "圣胡安",
        -3: "圣保罗",
        -2: "南乔治亚岛",
        -1: "亚速尔群岛",
         0: "伦敦",
         1: "柏林",
         2: "雅典",
         3: "莫斯科",
         4: "迪拜",
         5: "卡拉奇",
         6: "达卡",
         7: "曼谷",
         8: "北京",
         9: "东京",
        10: "悉尼",
        11: "所罗门群岛",
        12: "奥克兰"
    ]
}

private extension ClockDriftCalculator {
    static let secondsPerDay: Double = 24 * 3600
}
