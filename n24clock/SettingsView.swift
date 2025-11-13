import SwiftUI

struct SettingsView: View {
    let parameters: BiologicalClockParameters
    let onSave: (BiologicalClockParameters) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var cycleLengthInDays: Int
    @State private var referenceStart: Date
    @State private var wakeTime: Date
    @State private var sleepDurationMinutes: Int
    @State private var showPhaseAdjuster: Bool = false

    private static let sleepMinuteInterval: Int = SleepPreferenceDefaults.minuteStep
    private static let minimumSleepDuration: TimeInterval = SleepPreferenceDefaults.minDuration
    private static let maximumSleepDuration: TimeInterval = SleepPreferenceDefaults.maxDuration
    private static let defaultWakeOffset: TimeInterval = SleepPreferenceDefaults.defaultWakeOffset
    private static let defaultSleepDuration: TimeInterval = SleepPreferenceDefaults.defaultSleepDuration
    private static let cycleRange: ClosedRange<Int> = 10...60

    init(
        parameters: BiologicalClockParameters,
        onSave: @escaping (BiologicalClockParameters) -> Void,
        onReset: @escaping () -> Void
    ) {
        let sanitized = parameters.ensuringSleepPreferences()
        self.parameters = sanitized
        self.onSave = onSave
        self.onReset = onReset

        let initialCycle = Self.estimatedCycleLengthDays(for: sanitized.biologicalDayLength)
        _cycleLengthInDays = State(initialValue: initialCycle)
        _referenceStart = State(initialValue: sanitized.referenceStart)

        let wakeOffset = sanitized.preferredWakeOffset ?? Self.defaultWakeOffset
        _wakeTime = State(initialValue: Self.timeFrom(offset: wakeOffset))

        let initialSleep = sanitized.preferredSleepDuration ?? Self.defaultSleepDuration
        let clampedMinutes = Self.clampSleepMinutes(initialSleep)
        _sleepDurationMinutes = State(initialValue: clampedMinutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                biologicalClockSection
                sleepArcSection
                resetSection
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { saveChanges() }
                        .fontWeight(.semibold)
                        .controlSize(.large)
                        .glassyButtonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $showPhaseAdjuster) {
            PhaseAdjustmentSheet(
                stepMinutes: Self.sleepMinuteInterval,
                baseReferenceStart: referenceStart,
                onCancel: { showPhaseAdjuster = false },
                onConfirm: { delta in
                    applyPhaseAdjustment(delta)
                    showPhaseAdjuster = false
                }
            )
        }
        .onChange(of: cycleLengthInDays) { _ in
            enforceSleepDurationBounds()
        }
    }

    private var biologicalClockSection: some View {
        Section("非24小时生物钟") {
            VStack(alignment: .leading, spacing: 8) {
                Text("多长时间轮回一次生物钟")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Picker("多长时间轮回一次生物钟", selection: $cycleLengthInDays) {
                    ForEach(Self.cycleRange, id: \.self) { day in
                        Text("\(day) 天")
                            .tag(day)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: 140)

                Text("当前选择：\(cycleLengthInDays) 天")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(dayLengthCardDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("生物日长度", value: Self.dayLengthDescription(for: selectedBiologicalDayLength))
            phaseAdjustmentButton
            LabeledContent("当前相位参考点", value: Self.referenceFormatter.string(from: referenceStart))
        }
    }

    private var sleepArcSection: some View {
        Section("睡眠窗口") {
            DatePicker(
                "内在生物钟起床时间",
                selection: $wakeTime,
                displayedComponents: .hourAndMinute
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("睡眠时长")
                    Spacer()
                    Text(Self.durationDescription(for: TimeInterval(sleepDurationMinutes * 60)))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Picker("睡眠时长", selection: $sleepDurationMinutes) {
                    ForEach(sleepDurationOptions, id: \.self) { minutes in
                        Text(Self.durationDescription(for: TimeInterval(minutes * 60)))
                            .tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: 140)

                Text("范围 3-14 小时，刻度以 5 分钟为步进。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var resetSection: some View {
        Section("重新开始 Onboarding") {
            Button(role: .destructive) {
                onReset()
                dismiss()
            } label: {
                Text("重新开始并清除当前设置")
            }
        }
    }

    private var phaseAdjustmentButton: some View {
        Button {
            showPhaseAdjuster = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("相位微调")
                    Text("每次 ±5 分钟，推迟为正、提前为负")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var selectedBiologicalDayLength: TimeInterval {
        Self.dayLength(forCycleLength: cycleLengthInDays)
    }

    private var maxSleepDurationMinutes: Int { Self.maximumSleepDurationMinutes }

    private var sleepDurationOptions: [Int] {
        stride(
            from: Self.minimumSleepDurationMinutes,
            through: maxSleepDurationMinutes,
            by: Self.sleepMinuteInterval
        ).map { $0 }
    }

    private var dayLengthCardDescription: String {
        let hours = selectedBiologicalDayLength / 3600
        let driftHours = max(hours - 24, 0)
        if driftHours >= 1 {
            return String(format: "≈ %.2f 小时 | 每天约推迟 %.1f 小时", hours, driftHours)
        } else if driftHours > 0 {
            return String(format: "≈ %.2f 小时 | 每天约推迟 %.0f 分钟", hours, driftHours * 60)
        } else {
            return String(format: "≈ %.2f 小时", hours)
        }
    }

    private static var minimumSleepDurationMinutes: Int { Int(minimumSleepDuration / 60) }
    private static var maximumSleepDurationMinutes: Int { Int(maximumSleepDuration / 60) }

    private func enforceSleepDurationBounds() {
        let normalizedSeconds = SleepPreferenceDefaults.normalizedDuration(TimeInterval(sleepDurationMinutes * 60))
        sleepDurationMinutes = Int(normalizedSeconds / 60)
    }

    private func saveChanges() {
        let wakeOffset = Self.secondsFromMidnight(date: wakeTime)
        let sleepSeconds = SleepPreferenceDefaults.normalizedDuration(TimeInterval(sleepDurationMinutes * 60))
        let updatedParameters = BiologicalClockParameters(
            biologicalDayLength: selectedBiologicalDayLength,
            referenceStart: referenceStart,
            preferredWakeOffset: wakeOffset,
            preferredSleepDuration: sleepSeconds
        )
        onSave(updatedParameters)
        dismiss()
    }

    /// Positive delta delays the rhythm, negative delta advances it.
    private func applyPhaseAdjustment(_ delta: TimeInterval) {
        guard delta != 0 else { return }
        // Biological clock offset is computed as real-world time minus `referenceStart`.
        // Moving the reference forward by `delta` subtracts the same delta from every
        // computed offset, which delays upcoming events; moving it backward advances them.
        referenceStart = referenceStart.addingTimeInterval(delta)
    }

    private static func estimatedCycleLengthDays(for dayLength: TimeInterval) -> Int {
        let hours = max(dayLength / 3600, 24.01)
        let drift = hours - 24
        guard drift > 0 else { return cycleRange.lowerBound }
        let estimatedDays = Int(round(24 / drift))
        return min(max(estimatedDays, cycleRange.lowerBound), cycleRange.upperBound)
    }

    private static func dayLength(forCycleLength days: Int) -> TimeInterval {
        let clampedDays = min(max(days, cycleRange.lowerBound), cycleRange.upperBound)
        let hours = 24 + 24 / Double(clampedDays)
        return hours * 3600
    }

    private static func clampSleepMinutes(_ duration: TimeInterval) -> Int {
        let normalized = SleepPreferenceDefaults.normalizedDuration(duration)
        return Int(normalized / 60)
    }

    private static func dayLengthDescription(for interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0
            ? "\(hours) 小时"
            : "\(hours) 小时 \(minutes) 分"
    }

    private static func durationDescription(for interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return "\(minutes) 分钟"
        }
        if minutes == 0 {
            return "\(hours) 小时"
        }
        return "\(hours) 小时 \(minutes) 分"
    }

    private static func timeFrom(offset: TimeInterval) -> Date {
        let midnight = Calendar.current.startOfDay(for: Date())
        return midnight.addingTimeInterval(offset.truncatingRemainder(dividingBy: 24 * 3600))
    }

    private static func secondsFromMidnight(date: Date) -> TimeInterval {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0
        return TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    static let referenceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct PhaseAdjustmentSheet: View {
    let stepMinutes: Int
    let baseReferenceStart: Date
    let onCancel: () -> Void
    let onConfirm: (TimeInterval) -> Void

    @State private var adjustmentSteps: Int = 0

    private var stepSeconds: TimeInterval { TimeInterval(stepMinutes * 60) }
    private var totalDelta: TimeInterval { TimeInterval(adjustmentSteps) * stepSeconds }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前参考点")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(SettingsView.referenceFormatter.string(from: baseReferenceStart))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 24) {
                    Button(action: { decrement() }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                    }
                    .accessibilityLabel("提前 5 分钟")

                    VStack(spacing: 8) {
                        Text(deltaDescription)
                            .font(.title3.monospacedDigit())
                        Text("正值推迟，负值提前。步长 \(stepMinutes) 分钟。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: { increment() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                    }
                    .accessibilityLabel("推迟 5 分钟")
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("相位微调")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        onConfirm(totalDelta)
                    }
                    .disabled(adjustmentSteps == 0)
                }
            }
        }
    }

    private var deltaDescription: String {
        if adjustmentSteps == 0 {
            return "0 分钟"
        }
        let minutes = adjustmentSteps * stepMinutes
        return String(format: "%@ %d 分钟", minutes > 0 ? "+" : "-", abs(minutes))
    }

    private func increment() {
        adjustmentSteps += 1
    }

    private func decrement() {
        adjustmentSteps -= 1
    }
}

#Preview {
    let params = BiologicalClockParameters(
        biologicalDayLength: 25 * 3600,
        referenceStart: Date(),
        preferredWakeOffset: 7 * 3600,
        preferredSleepDuration: 8 * 3600
    )
    SettingsView(parameters: params, onSave: { _ in }, onReset: { })
}
