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
                let totalHours = state.dayLength / 3600
                let components = state.offsetComponents
                let formattedCurrentTime = String(
                    format: "%02d:%02d:%02d",
                    components.hour ?? 0,
                    components.minute ?? 0,
                    components.second ?? 0
                )

                VStack(spacing: 32) {
                    Text("内在生物时间")
                        .font(.title.bold())

                    Text(formattedCurrentTime)
                        .font(.system(size: 48, weight: .medium, design: .monospaced))

                    BiologicalClockDial(state: state)
                        .frame(maxWidth: 360)

                    VStack(spacing: 8) {
                        Text("当前为第 \(state.dayIndex) 个生物日")
                            .font(.headline)
                        Text("距离下一次生物日还有 \(remainingHours) 小时 \(remainingMinutes) 分钟")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(String(format: "每个生物日 ≈ %.2f 小时", totalHours))
                        .font(.title3)
                        .foregroundStyle(Color.blue)
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

private struct BiologicalClockDial: View {
    let state: BiologicalClock.State

    private var progress: Double {
        state.progress
    }

    var body: some View {
        GeometryReader { geometry in
            let dimension = min(geometry.size.width, geometry.size.height)
            let radius = dimension / 2
            let outerPadding: CGFloat = 24
            let drawingRadius = radius - outerPadding
            let ticks = tickMarks(totalHours: state.dayLength / 3600)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = drawingRadius

                    // 基础圆盘
                    var base = Path()
                    base.addArc(center: center,
                                radius: radius,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360),
                                clockwise: false)
                    context.stroke(base,
                                    with: .color(Color.secondary.opacity(0.25)),
                                    style: StrokeStyle(lineWidth: 14, lineCap: .round))

                    // 进度弧线
                    var progressPath = Path()
                    progressPath.addArc(center: center,
                                        radius: radius,
                                        startAngle: .degrees(-90),
                                        endAngle: .degrees(-90 + 360 * progress),
                                        clockwise: false)
                    context.stroke(progressPath,
                                    with: .color(Color.accentColor),
                                    style: StrokeStyle(lineWidth: 14, lineCap: .round))

                    // 刻度
                    for tick in ticks {
                        let angle = Angle(degrees: tick.fraction * 360 - 90)
                        let cosValue = CGFloat(cos(angle.radians))
                        let sinValue = CGFloat(sin(angle.radians))
                        let outerPoint = CGPoint(
                            x: center.x + cosValue * radius,
                            y: center.y + sinValue * radius
                        )
                        let innerPoint = CGPoint(
                            x: center.x + cosValue * (radius - tick.length),
                            y: center.y + sinValue * (radius - tick.length)
                        )
                        var tickPath = Path()
                        tickPath.move(to: innerPoint)
                        tickPath.addLine(to: outerPoint)
                        context.stroke(tickPath,
                                       with: .color(tick.isMajor ? .primary : .secondary.opacity(0.6)),
                                       style: StrokeStyle(lineWidth: tick.isMajor ? 2 : 1, lineCap: .round))
                    }

                    // 指针
                    let pointerLength = radius - 24
                    let pointerAngle = Angle(degrees: progress * 360 - 90)
                    let pointerCos = CGFloat(cos(pointerAngle.radians))
                    let pointerSin = CGFloat(sin(pointerAngle.radians))
                    let pointerEnd = CGPoint(
                        x: center.x + pointerCos * pointerLength,
                        y: center.y + pointerSin * pointerLength
                    )
                    var pointerPath = Path()
                    pointerPath.move(to: center)
                    pointerPath.addLine(to: pointerEnd)
                    context.stroke(pointerPath,
                                   with: .color(.red),
                                   style: StrokeStyle(lineWidth: 1, lineCap: .round))
                }

                // 中心圆点
                Circle()
                    .fill(.background)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)

                // 刻度标签
                ForEach(ticks, id: \.self) { tick in
                    let angle = Angle(degrees: tick.fraction * 360 - 90)
                    let labelRadius = drawingRadius - 36
                    let cosValue = CGFloat(cos(angle.radians))
                    let sinValue = CGFloat(sin(angle.radians))
                    let labelOffset = CGPoint(
                        x: center.x + cosValue * labelRadius,
                        y: center.y + sinValue * labelRadius
                    )
                    Text(tick.label)
                        .font(.caption2)
                        .foregroundStyle(tick.isMajor ? .primary : .secondary)
                        .position(labelOffset)
                }
            }
            .frame(width: dimension, height: dimension)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func tickMarks(totalHours: Double) -> [TickMark] {
        guard totalHours > 0 else { return [] }

        let step: Double
        switch totalHours {
        case ..<12:
            step = 1
        case ..<24:
            step = 2
        case ..<48:
            step = 3
        case ..<72:
            step = 4
        default:
            step = 6
        }

        var marks: [TickMark] = []
        var current: Double = 0
        let epsilon = 0.001
        while current <= totalHours + epsilon {
            let clamped = min(current, totalHours)
            let fraction = clamped / totalHours
            let isMajor = abs(clamped.truncatingRemainder(dividingBy: (step * 2))) < epsilon || clamped == 0 || abs(clamped - totalHours) < epsilon
            let isEnd = abs(clamped - totalHours) < epsilon
            let label: String
            if isEnd {
                label = ""
            } else if abs(clamped.rounded() - clamped) < 0.01 {
                label = String(format: "%.0f", clamped)
            } else {
                label = String(format: "%.1f", clamped)
            }
            marks.append(TickMark(value: clamped, fraction: fraction, label: label, isMajor: isMajor))
            current += step
        }

        if let last = marks.last, abs(last.value - totalHours) < epsilon {
            marks[marks.count - 1] = TickMark(value: totalHours,
                                              fraction: 1,
                                              label: "",
                                              isMajor: true)
        } else {
            marks.append(TickMark(value: totalHours,
                                  fraction: 1,
                                  label: "",
                                  isMajor: true))
        }

        return marks
    }

    private struct TickMark: Hashable {
        let value: Double
        let fraction: Double
        let label: String
        let isMajor: Bool

        var length: CGFloat {
            isMajor ? 18 : 12
        }
    }
}
