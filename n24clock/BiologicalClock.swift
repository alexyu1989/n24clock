import Foundation

// MARK: - 生物钟核心逻辑

/// 描述用户非24小时生物钟所需的核心参数。
struct BiologicalClockParameters: Equatable, Codable {
    /// 单个生物日的长度，单位为秒。
    let biologicalDayLength: TimeInterval 
    /// 对应生物日0且偏移为0的现实世界时间戳。
    let referenceStart: Date
    /// 从 referenceStart 开始的生物日编号（默认0）。
    let referenceDayIndex: Int

    init(biologicalDayLength: TimeInterval, referenceStart: Date, referenceDayIndex: Int = 0) {
        precondition(biologicalDayLength > 0, "Biological day length must be positive.")
        self.biologicalDayLength = biologicalDayLength
        self.referenceStart = referenceStart
        self.referenceDayIndex = referenceDayIndex
    }
}

/// 根据生物钟参数推导时间信息的工具结构。
struct BiologicalClock {
    let parameters: BiologicalClockParameters

    init(parameters: BiologicalClockParameters) {
        self.parameters = parameters
    }

    /// 描述特定时刻在生物节律中位置的快照。
    struct State: Equatable {
        let dayIndex: Int
        let offsetWithinDay: TimeInterval
        let dayLength: TimeInterval

        /// 当前生物日的进度，范围 0...1。
        var progress: Double {
            guard dayLength > 0 else { return 0 }
            return min(max(offsetWithinDay / dayLength, 0), 1)
        }

        /// 距离下一个生物日开始所剩的时间。
        var remainingInDay: TimeInterval {
            max(dayLength - offsetWithinDay, 0)
        }

        /// 当日偏移量的小时/分钟/秒拆分。
        var offsetComponents: DateComponents {
            let totalSeconds = Int(offsetWithinDay.rounded(.down))
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            return DateComponents(hour: hours, minute: minutes, second: seconds)
        }
    }

    /// 返回指定现实时间对应的生物状态。
    func state(at date: Date) -> State {
        let dayLength = parameters.biologicalDayLength
        precondition(dayLength > 0, "Biological day length must be positive.")

        let elapsed = date.timeIntervalSince(parameters.referenceStart)
        let completedDays = Int(floor(elapsed / dayLength))
        var offset = elapsed - Double(completedDays) * dayLength
        var dayIndex = parameters.referenceDayIndex + completedDays

        if offset < 0 {
            offset += dayLength
            dayIndex -= 1
        }

        return State(dayIndex: dayIndex, offsetWithinDay: offset, dayLength: dayLength)
    }

    /// 计算目标生物日偏移下一次在现实中的发生时间。
    func nextOccurrence(of targetOffset: TimeInterval, after date: Date) -> Date {
        let normalizedTarget = normalizedOffset(targetOffset)
        let state = state(at: date)

        if normalizedTarget > state.offsetWithinDay {
            let delta = normalizedTarget - state.offsetWithinDay
            return date.addingTimeInterval(delta)
        } else {
            let delta = (parameters.biologicalDayLength - state.offsetWithinDay) + normalizedTarget
            return date.addingTimeInterval(delta)
        }
    }

    private func normalizedOffset(_ rawOffset: TimeInterval) -> TimeInterval {
        let length = parameters.biologicalDayLength
        guard length > 0 else { return 0 }

        let modulo = rawOffset.truncatingRemainder(dividingBy: length)
        return modulo >= 0 ? modulo : modulo + length
    }
}

// MARK: - 用户输入辅助方法

extension BiologicalClockParameters {
    /// 配置生物钟时用于承载原始用户输入的结构体。
    struct UserInput {
        let hours: Int
        let minutes: Int
        let seconds: Int
        let referenceStart: Date
        let referenceDayIndex: Int

        public init(hours: Int, minutes: Int, seconds: Int = 0, referenceStart: Date, referenceDayIndex: Int = 0) {
            self.hours = hours
            self.minutes = minutes
            self.seconds = seconds
            self.referenceStart = referenceStart
            self.referenceDayIndex = referenceDayIndex
        }

        /// 将用户输入的组件转换为规范化参数。
        func buildParameters() throws -> BiologicalClockParameters {
            let totalSeconds = try Self.validateAndComputeDayLength(hours: hours, minutes: minutes, seconds: seconds)
            return BiologicalClockParameters(
                biologicalDayLength: totalSeconds,
                referenceStart: referenceStart,
                referenceDayIndex: referenceDayIndex
            )
        }

        private static func validateAndComputeDayLength(hours: Int, minutes: Int, seconds: Int) throws -> TimeInterval {
            guard hours >= 0, minutes >= 0, seconds >= 0 else {
                throw InputError.negativeComponent
            }

            let totalSeconds = TimeInterval(hours * 3600 + minutes * 60 + seconds)
            guard totalSeconds > 0 else {
                throw InputError.zeroLengthDay
            }

            return totalSeconds
        }

        enum InputError: Error {
            case negativeComponent
            case zeroLengthDay
        }
    }

    /// 为直接数值输入（例如滑杆）提供的便捷工厂方法。
    static func from(dayLength: TimeInterval, referenceStart: Date, referenceDayIndex: Int = 0) throws -> BiologicalClockParameters {
        guard dayLength > 0 else {
            throw UserInput.InputError.zeroLengthDay
        }
        return BiologicalClockParameters(
            biologicalDayLength: dayLength,
            referenceStart: referenceStart,
            referenceDayIndex: referenceDayIndex
        )
    }
}
