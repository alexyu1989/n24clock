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
                let components = state.offsetComponents
                let formatted = String(format: "%02d:%02d:%02d", components.hour ?? 0, components.minute ?? 0, components.second ?? 0)
                let remaining = state.remainingInDay
                let remainingHours = Int(remaining) / 3600
                let remainingMinutes = (Int(remaining) % 3600) / 60

                VStack(spacing: 24) {
                    Text("内在生物时间")
                        .font(.title.bold())

                    Text(formatted)
                        .font(.system(size: 48, weight: .medium, design: .monospaced))

                    VStack(spacing: 8) {
                        Text("当前为第 \(state.dayIndex) 个生物日")
                            .font(.headline)
                        Text("距离下一次生物日还有 \(remainingHours) 小时 \(remainingMinutes) 分钟")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding()
            }
            .navigationTitle("n24 Clock")
            .toolbar {
                Button("重新设置", action: onReset)
            }
        }
    }
}

#Preview {
    ContentView()
}
