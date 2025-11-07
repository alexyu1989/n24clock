import SwiftUI
import UIKit

struct OnboardingGuideView: View {
    enum Step: Int, CaseIterable {
        case cycleLength
        case wakeActual
        case wakePreference
        case sleepDuration

        var title: String {
            switch self {
            case .cycleLength: return "您的生物钟一个轮回是多少天？"
            case .wakeActual: return "今天最近一次起床是几点的？"
            case .wakePreference: return "希望对齐到生物钟起床时间是几点？"
            case .sleepDuration: return "通常会睡多久呢？"
            }
        }
    }

    let onComplete: (BiologicalClockParameters) -> Void

    private static let wakeMinuteInterval: Int = 5
    private static let defaultSleepDuration: TimeInterval = 7 * 3600
    private static let minimumSleepDuration: TimeInterval = TimeInterval(wakeMinuteInterval * 60)
    private static let maxSleepDurationMinutes: Int = 23 * 60 + 55

    @State private var step: Step = .cycleLength
    @State private var cycleLengthInDays: Int = 30
    @State private var wakeTime: Date = Self.roundedDate(Date(), minuteInterval: Self.wakeMinuteInterval)
    @State private var preferredWakeHour: Int = 6
    @State private var sleepDuration: TimeInterval = Self.defaultSleepDuration
    @State private var showError: Bool = false

    private var nextButtonTitle: String {
        step == .sleepDuration ? "完成设置" : "下一步"
    }

    private var progress: Double {
        Double(step.rawValue + 1) / Double(Step.allCases.count)
    }

    private var stepDescription: String {
        "步骤 \(step.rawValue + 1) / \(Step.allCases.count)"
    }

    private var canContinue: Bool {
        switch step {
        case .cycleLength:
            return cycleLengthInDays > 1
        case .wakeActual, .wakePreference:
            return true
        case .sleepDuration:
            return sleepDuration >= Self.minimumSleepDuration
        }
    }

    private var preferredWakeOptions: [Int] { [5, 6, 7, 8, 9] }

    private var biologicalDayLengthHours: Double? {
        guard cycleLengthInDays > 0 else { return nil }
        let days = Double(cycleLengthInDays)
        return 24 + 24 / days
    }

    private var dayLengthDescription: String {
        guard let hours = biologicalDayLengthHours else {
            return "请输入大于 1 的天数"
        }
        return String(format: "≈ %.2f 小时", hours)
    }

    private var dailyDriftDescription: String {
        guard let hours = biologicalDayLengthHours else { return "" }
        let driftHours = hours - 24
        guard driftHours > 0 else { return "节律接近标准 24 小时" }

        if driftHours >= 1 {
            return String(format: "每天约推迟 %.1f 小时", driftHours)
        } else {
            let minutes = driftHours * 60
            return String(format: "每天约推迟 %.0f 分钟", minutes)
        }
    }

    private func goForward() {
        switch step {
        case .cycleLength:
            step = .wakeActual
        case .wakeActual:
            step = .wakePreference
        case .wakePreference:
            step = .sleepDuration
        case .sleepDuration:
            completeSetup()
        }
    }

    private func goBackward() {
        switch step {
        case .cycleLength:
            break
        case .wakeActual:
            step = .cycleLength
        case .wakePreference:
            step = .wakeActual
        case .sleepDuration:
            step = .wakePreference
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private var wakeDescription: String {
        Self.timeFormatter.string(from: wakeTime)
    }

    private var sleepDurationDescription: String {
        let totalMinutes = Int(sleepDuration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if minutes == 0 {
            return "\(hours) 小时"
        } else {
            return "\(hours) 小时 \(minutes) 分钟"
        }
    }

    private func completeSetup() {
        guard let hours = biologicalDayLengthHours else {
            showError = true
            return
        }

        let dayLengthSeconds = hours * 3600
        let wakeOffset = TimeInterval(preferredWakeHour) * 3600
        let referenceStart = wakeTime.addingTimeInterval(-wakeOffset)
        let clampedSleepDuration = max(sleepDuration, Self.minimumSleepDuration)
        let parameters = BiologicalClockParameters(
            biologicalDayLength: dayLengthSeconds,
            referenceStart: referenceStart,
            preferredWakeOffset: wakeOffset,
            preferredSleepDuration: clampedSleepDuration
        )
        onComplete(parameters)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemIndigo).opacity(0.35), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(stepDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(step.title)
                        .font(.title2.weight(.semibold))

                    ProgressView(value: progress)
                        .tint(.accentColor)
                        .animation(.easeInOut, value: progress)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                contentCard

                Spacer(minLength: 0)

                actionBar
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .animation(.easeInOut, value: step)
        .alert("请检查输入", isPresented: $showError) {
            Button("好的", role: .cancel) { }
        } message: {
            Text("请输入大于 1 天的完整轮回。")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .cycleLength:
            VStack(alignment: .leading, spacing: 16) {
                Text("请选择从起床时间回到同一时间大约需要多少天。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $cycleLengthInDays) {
                        ForEach(10...60, id: \.self) { day in
                            Text("\(day) 天")
                                .tag(day)
                        }
                    }
                    .pickerStyle(.wheel)

                    Text("\(cycleLengthInDays) 天")
                        .font(.headline)
                    Text(dayLengthDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(dailyDriftDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        case .wakeActual:
            VStack(alignment: .leading, spacing: 16) {
                Text("请在下方选择您今天实际醒来的时间。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                DatePicker("", selection: wakeTimeBinding, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .onAppear { Self.configureMinuteInterval() }

                Text("当前选择：今天 \(wakeDescription)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .wakePreference:
            VStack(alignment: .leading, spacing: 20) {
                Text("选择一个你希望长期保持的理想起床时间，我们会把今天实际醒来的那一刻对齐到这个时间点，之后的生物日都会以它作为 0 点。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("", selection: $preferredWakeHour) {
                    ForEach(preferredWakeOptions, id: \.self) { hour in
                        Text("\(hour):00")
                            .tag(hour)
                    }
                }
                .pickerStyle(.segmented)

                alignmentPreview

                Text("例：如果今天实际 9:30 醒来，而你选择 7:00，我们会把今天这次醒来当作 7:00，并据此推算接下来的生物日。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .sleepDuration:
            VStack(alignment: .leading, spacing: 16) {
                Text("告诉我们一个大概的睡眠时长，方便在表盘外侧标注出睡眠区间。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                DatePicker("", selection: sleepDurationBinding, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .onAppear { Self.configureMinuteInterval() }

                Text("当前选择：\(sleepDurationDescription)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("我们会默认在理想起床时间前倒推这个时长，来绘制睡眠弧线。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            content

            Divider()

            helperTip
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 12)
        )
    }

    private var helperTip: some View {
        let text: String
        switch step {
        case .cycleLength:
            text = "如果不确定，请回想上一次醒来自然调整到当前节律大约花了多少天。"
        case .wakeActual:
            text = "选择实际醒来的时间时，分钟会按 5 分钟跳动，便于快速输入。"
        case .wakePreference:
            text = "将今天的实际醒来对齐到理想起床时间，可以让之后的节律都围绕它展开。"
        case .sleepDuration:
            text = "睡眠弧线会以理想起床时间为终点，倒推你选择的时长，帮助你直观查看睡眠区。"
        }

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundStyle(.yellow)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 16) {
            if step != .cycleLength {
                Button("上一步", action: goBackward)
                    .buttonStyle(SecondaryActionButtonStyle())
            }

            Button(nextButtonTitle, action: goForward)
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.4)
        }
    }

    private var alignmentPreview: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("实际醒来", systemImage: "alarm.waves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(wakeDescription)
                    .font(.headline)
            }

            Image(systemName: "arrow.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 6) {
                Label("对齐到内在生物钟", systemImage: "target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%02d:00", preferredWakeHour))
                    .font(.headline)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.9))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }

    private var wakeTimeBinding: Binding<Date> {
        Binding(
            get: { wakeTime },
            set: { newValue in
                let rounded = Self.roundedDate(newValue, minuteInterval: Self.wakeMinuteInterval)
                if rounded != wakeTime {
                    wakeTime = rounded
                }
            }
        )
    }

    private var sleepDurationBinding: Binding<Date> {
        Binding(
            get: { Self.date(forDuration: sleepDuration) },
            set: { newValue in
                let duration = Self.durationValue(from: newValue, minuteInterval: Self.wakeMinuteInterval)
                if duration != sleepDuration {
                    sleepDuration = duration
                }
            }
        )
    }

    private static func roundedDate(_ date: Date, minuteInterval: Int) -> Date {
        guard minuteInterval > 1 else { return date }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        if let minute = components.minute {
            let remainder = minute % minuteInterval
            components.minute = minute - remainder
        }
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    private static func date(forDuration duration: TimeInterval) -> Date {
        let totalMinutes = Int(duration / 60)
        let sanitizedMinutes = min(max(totalMinutes, wakeMinuteInterval), maxSleepDurationMinutes)
        let hours = sanitizedMinutes / 60
        let minutes = sanitizedMinutes % 60
        return date(forHours: hours, minutes: minutes)
    }

    private static func durationValue(from date: Date, minuteInterval: Int) -> TimeInterval {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let minimumMinutes = minuteInterval
        let clampedMinutes = min(max(minutes, minimumMinutes), maxSleepDurationMinutes)
        let snappedMinutes = clampedMinutes - (clampedMinutes % minuteInterval)
        return TimeInterval(snappedMinutes * 60)
    }

    private static func date(forHours hours: Int, minutes: Int) -> Date {
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = hours
        components.minute = minutes
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private static func configureMinuteInterval() {
        UIDatePicker.appearance().minuteInterval = wakeMinuteInterval
    }
}

#Preview {
    OnboardingGuideView { _ in }
}

// MARK: - Button Styles

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor)
                    .shadow(color: Color.accentColor.opacity(0.2), radius: 10, x: 0, y: 8)
            )
            .foregroundStyle(Color.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.9))
                    )
            )
            .foregroundStyle(Color.accentColor)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
