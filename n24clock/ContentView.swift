import CoreLocation
import SwiftUI

struct ContentView: View {
    @StateObject private var settings = ClockSettings()

    var body: some View {
        if let parameters = settings.parameters {
            ClockDashboardView(parameters: parameters) {
                settings.reset()
            }
        } else {
            OnboardingGuideView { parameters in
                settings.parameters = parameters
            }
        }
    }
}

private struct ClockDashboardView: View {
    let parameters: BiologicalClockParameters
    let onReset: () -> Void

    @StateObject private var sunriseService = SunriseService()

    private var clock: BiologicalClock {
        BiologicalClock(parameters: parameters)
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                dashboard(for: context.date)
            }
            .navigationTitle("非24小时生物钟")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("重新设置", action: onReset)
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            sunriseService.start()
        }
    }

    @ViewBuilder
    private func dashboard(for date: Date) -> some View {
        let state = clock.state(at: date)
        let formattedTime = Self.formattedBiologicalTime(from: state.offsetComponents)
        let remainingText = Self.remainingDescription(for: state.remainingInDay)
        let dayLengthText = Self.dayLengthDescription(for: state.dayLength)
        let sleepCountdown = countdownDescription(to: sleepStartOffset, at: date)
        let sunriseCountdown = sunriseCountdownDescription(at: date)

        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemIndigo).opacity(0.45),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    mainCard(
                        state: state,
                        formattedTime: formattedTime,
                        sleepCountdown: sleepCountdown,
                        remainingText: remainingText,
                        dayLengthText: dayLengthText,
                        sunriseCountdown: sunriseCountdown,
                        date: date
                    )
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
            }
        }
    }

    private func mainCard(
        state: BiologicalClock.State,
        formattedTime: String,
        sleepCountdown: String,
        remainingText: String,
        dayLengthText: String,
        sunriseCountdown: String,
        date: Date
    ) -> some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

        return VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("内在生物钟时间")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("BT \(formattedTime)")
                    .font(.title)
                    .fontWeight(.bold)
                    .fontDesign(.monospaced)
                    .contentTransition(.numericText(value: state.offsetWithinDay))
                    .animation(.easeInOut(duration: 0.25), value: formattedTime)
                ClockDriftInfoView(state: state, date: date)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            BiologicalClockDial(state: state, sleepArc: sleepArc)
                .frame(maxWidth: 320, maxHeight: 320)
                .frame(maxWidth: .infinity)

            LazyVGrid(columns: columns, spacing: 16) {
                DashboardInfoTile(title: "距离下一生物日", value: remainingText, icon: "hourglass.bottomhalf.fill")
                DashboardInfoTile(title: "生物钟长度", value: dayLengthText, icon: "ruler")
                DashboardInfoTile(title: "距离睡觉", value: sleepCountdown, icon: "bed.double.fill")
                DashboardInfoTile(title: "距离日出", value: sunriseCountdown, icon: "sunrise.fill")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.95))
                .shadow(color: Color.black.opacity(0.16), radius: 24, x: 0, y: 16)
        )
    }

    private var sleepStartOffset: TimeInterval? {
        guard let wakeOffset = parameters.preferredWakeOffset,
              let duration = parameters.preferredSleepDuration,
              duration > 0 else { return nil }
        return wakeOffset - duration
    }

    private var sleepArc: BiologicalClockDial.SleepArc? {
        guard let wakeOffset = parameters.preferredWakeOffset,
              let duration = parameters.preferredSleepDuration,
              duration > 0 else { return nil }
        let dayLength = parameters.biologicalDayLength
        guard dayLength > 0 else { return nil }

        let clampedDuration = min(duration, dayLength)
        if clampedDuration >= dayLength {
            return BiologicalClockDial.SleepArc(startFraction: 0,
                                                endFraction: 1,
                                                wrapsAround: false)
        }
        let startFraction = normalizedFraction(for: wakeOffset - clampedDuration, dayLength: dayLength)
        let endFraction = normalizedFraction(for: wakeOffset, dayLength: dayLength)
        let wraps = startFraction > endFraction && clampedDuration < dayLength

        return BiologicalClockDial.SleepArc(startFraction: startFraction,
                                            endFraction: endFraction,
                                            wrapsAround: wraps)
    }

    private func countdownDescription(to targetOffset: TimeInterval?, at date: Date) -> String {
        guard let offset = targetOffset else { return "未设定" }
        let nextDate = clock.nextOccurrence(of: offset, after: date)
        let interval = max(0, nextDate.timeIntervalSince(date))
        return Self.remainingDescription(for: interval)
    }

    private func sunriseCountdownDescription(at date: Date) -> String {
        if let sunriseDate = sunriseService.nextSunrise(after: date) {
            return Self.remainingDescription(for: sunriseDate.timeIntervalSince(date))
        }

        switch sunriseService.authorizationStatus {
        case .denied, .restricted:
            return "未授权"
        case .notDetermined:
            return "请求权限"
        default:
            return sunriseService.lastError == nil ? "定位中" : "定位失败"
        }
    }

    private func normalizedFraction(for offset: TimeInterval, dayLength: TimeInterval) -> Double {
        guard dayLength > 0 else { return 0 }
        var value = offset.truncatingRemainder(dividingBy: dayLength)
        if value < 0 { value += dayLength }
        return value / dayLength
    }

    private static func formattedBiologicalTime(from components: DateComponents) -> String {
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private static func remainingDescription(for interval: TimeInterval) -> String {
        let clamped = max(Int(interval.rounded(.down)), 0)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let seconds = clamped % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    private static func dayLengthDescription(for interval: TimeInterval) -> String {
        let totalMinutes = Int(round(interval / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }
}

private struct DashboardInfoTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.headline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.9))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }
}

#Preview {
    ContentView()
}
