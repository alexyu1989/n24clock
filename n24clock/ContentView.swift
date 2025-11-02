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

    private var clock: BiologicalClock {
        BiologicalClock(parameters: parameters)
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let state = clock.state(at: context.date)
                let remaining = state.remainingInDay
                let remainingHours = Int(remaining) / 3600
                let remainingMinutes = (Int(remaining) % 3600) / 60
                let components = state.offsetComponents
                let totalSeconds = state.dayLength
                let totalMinutes = Int(round(totalSeconds / 60))
                let hoursPerDay = totalMinutes / 60
                let minutesPerDay = totalMinutes % 60
                let formattedCurrentTime = String(
                    format: "%02d:%02d:%02d",
                    components.hour ?? 0,
                    components.minute ?? 0,
                    components.second ?? 0
                )

                VStack(spacing: 32) {
                    Text("BT"+formattedCurrentTime)
                        .font(.system(size: 48, weight: .medium, design: .monospaced))

                    BiologicalClockDial(state: state)
                        .frame(maxWidth: 320)

                    ClockDriftInfoView(state: state, date: context.date)

//                    VStack(spacing: 8) {
//                        Text("当前为第 \(state.dayIndex) 个生物日")
//                            .font(.headline)
//                        Text("距离下一次生物日还有 \(remainingHours) 小时 \(remainingMinutes) 分钟")
//                            .font(.subheadline)
//                            .foregroundStyle(.secondary)
//                    }

                    Spacer()

                    Text("🧬 您的一天时长 \(hoursPerDay) 小时 \(minutesPerDay) 分钟")
                        .font(.title3)
                        .foregroundStyle(Color.blue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding()
            }
            .navigationTitle("非24小时生物钟")
            .toolbar {
                Button("重新设置", action: onReset)
            }
        }
    }
}

#Preview {
    ContentView()
}
