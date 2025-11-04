import SwiftUI

struct OnboardingGuideView: View {
    enum Step: Int, CaseIterable {
        case cycleLength
        case wakeSetup

        var title: String {
            switch self {
            case .cycleLength: return "您的生物钟一个轮回是多少天？"
            case .wakeSetup: return "今天您几点起床的？"
            }
        }
    }

    let onComplete: (BiologicalClockParameters) -> Void

    @State private var step: Step = .cycleLength
    @State private var cycleLengthInDays: Int = 30
    @State private var wakeTime: Date = Date()
    @State private var preferredWakeHour: Int = 6
    @State private var showError: Bool = false

    private var nextButtonTitle: String {
        step == .wakeSetup ? "完成" : "下一步"
    }

    private var canContinue: Bool {
        switch step {
        case .cycleLength:
            return cycleLengthInDays > 1
        case .wakeSetup:
            return true
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
            step = .wakeSetup
        case .wakeSetup:
            completeSetup()
        }
    }

    private func goBackward() {
        if step == .wakeSetup {
            step = .cycleLength
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

    private func completeSetup() {
        guard let hours = biologicalDayLengthHours else {
            showError = true
            return
        }

        let dayLengthSeconds = hours * 3600
        let wakeOffset = TimeInterval(preferredWakeHour) * 3600
        let referenceStart = wakeTime.addingTimeInterval(-wakeOffset)
        let parameters = BiologicalClockParameters(
            biologicalDayLength: dayLengthSeconds,
            referenceStart: referenceStart,
            referenceDayIndex: 0
        )
        onComplete(parameters)
    }

    var body: some View {
        VStack(spacing: 32) {
            Text(step.title)
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack {
                if step != .cycleLength {
                    Button("上一步", action: goBackward)
                }

                Spacer()

                Button(nextButtonTitle, action: goForward)
                    .disabled(!canContinue)
            }
        }
        .padding()
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
        case .wakeSetup:
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("请在下方选择您今天实际醒来的时间（以当前设备时区计）。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DatePicker("", selection: $wakeTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()

                    Text("当前选择：今天 \(wakeDescription)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("你希望匹配到你的生物钟起床时间是几点？")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $preferredWakeHour) {
                        ForEach(preferredWakeOptions, id: \.self) { hour in
                            Text("\(hour):00")
                                .tag(hour)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
}

#Preview {
    OnboardingGuideView { _ in }
}
