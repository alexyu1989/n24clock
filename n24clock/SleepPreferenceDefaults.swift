import Foundation

enum SleepPreferenceDefaults {
    static let minuteStep: Int = 5
    static let minDuration: TimeInterval = 3 * 3600
    static let maxDuration: TimeInterval = 14 * 3600
    static let defaultWakeOffset: TimeInterval = 6 * 3600
    static let defaultSleepDuration: TimeInterval = 7.5 * 3600

    private static var stepInSeconds: TimeInterval {
        TimeInterval(minuteStep * 60)
    }

    static func normalizedDuration(_ duration: TimeInterval) -> TimeInterval {
        let floored = floor(duration / stepInSeconds) * stepInSeconds
        return min(max(floored, minDuration), maxDuration)
    }

    static func normalizedDurationOrDefault(_ duration: TimeInterval?) -> TimeInterval {
        normalizedDuration(duration ?? defaultSleepDuration)
    }
}

extension BiologicalClockParameters {
    func ensuringSleepPreferences() -> BiologicalClockParameters {
        BiologicalClockParameters(
            biologicalDayLength: biologicalDayLength,
            referenceStart: referenceStart,
            preferredWakeOffset: preferredWakeOffset ?? SleepPreferenceDefaults.defaultWakeOffset,
            preferredSleepDuration: SleepPreferenceDefaults.normalizedDurationOrDefault(preferredSleepDuration)
        )
    }
}
