import SwiftUI

struct BiologicalClockDial: View {
    let state: BiologicalClock.State

    private var progress: Double {
        state.progress
    }

    var body: some View {
        GeometryReader { geometry in
            let dimension = min(geometry.size.width, geometry.size.height)
            let radius = dimension / 2
            let outerPadding: CGFloat = 0 // padding 默认是0
            let drawingRadius = radius - outerPadding
            let ticks = tickMarks(totalHours: state.dayLength / 3600)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = drawingRadius

                    // 表盘填充
                    var fillCircle = Path()
                    fillCircle.addArc(center: center,
                                      radius: radius,
                                      startAngle: .degrees(0),
                                      endAngle: .degrees(360),
                                      clockwise: false)
                    context.fill(fillCircle,
                                 with: .color(Color(uiColor: .tertiarySystemFill)))

                    // 外圈边框
//                    var border = Path()
//                    border.addArc(center: center,
//                                  radius: radius,
//                                  startAngle: .degrees(0),
//                                  endAngle: .degrees(360),
//                                  clockwise: false)
//                    context.stroke(border,
//                                   with: .color(Color.primary.opacity(1)),
//                                    style: StrokeStyle(lineWidth: 1))

                    // 刻度
                    
                    let tickRadius = radius - 6
                    for tick in ticks {
                        let angle = Angle(degrees: tick.fraction * 360 - 90)
                        let cosValue = CGFloat(cos(angle.radians))
                        let sinValue = CGFloat(sin(angle.radians))
                        let outerPoint = CGPoint(
                            x: center.x + cosValue * tickRadius,
                            y: center.y + sinValue * tickRadius
                        )
                        let innerPoint = CGPoint(
                            x: center.x + cosValue * (tickRadius - tick.length),
                            y: center.y + sinValue * (tickRadius - tick.length)
                        )
                        var tickPath = Path()
                        tickPath.move(to: innerPoint)
                        tickPath.addLine(to: outerPoint)
                        context.stroke(tickPath,
                                       with: .color(tick.isMajor ? .primary : .secondary.opacity(1)),
                                       style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    }

                    // 指针
                    let pointerLength = radius - 20
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
                    context.drawLayer { layer in
                        layer.addFilter(.shadow(color: .blue.opacity(0.6),
                                                radius: 0,
                                                x: 1.5,
                                                y: 1.5))
                        layer.stroke(pointerPath,
                                     with: .color(.red),
                                     style: StrokeStyle(lineWidth: 1))
                    }
                }

                // 中心圆点
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                    .shadow(color: .blue.opacity(0.6), radius: 0, x:1.5, y: 1.5)
                
                // 刻度标签
                ForEach(ticks, id: \.self) { tick in
                    if !tick.label.isEmpty {
                        let angle = Angle(degrees: tick.fraction * 360 - 90)
                        let labelRadius = drawingRadius - 36
                        let cosValue = CGFloat(cos(angle.radians))
                        let sinValue = CGFloat(sin(angle.radians))
                        let labelOffset = CGPoint(
                            x: center.x + cosValue * labelRadius,
                            y: center.y + sinValue * labelRadius
                        )
                        Text(tick.label)
                            .font(.custom("BodoniSvtyTwoOSITCTT-BookIt", size: 22, relativeTo: .body))
                            .kerning(1.5)
                            .foregroundStyle(.primary)
                            .position(labelOffset)
                    }
                }
            }
            .frame(width: dimension, height: dimension)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private extension BiologicalClockDial {
    func tickMarks(totalHours: Double) -> [TickMark] {
        guard totalHours > 0 else { return [] }

        let epsilon = 0.000_1
        let step = 0.25 // 15 分钟
        var marks: [TickMark] = []
        var current = 0.0

        while current <= totalHours + epsilon {
            let clamped = min(current, totalHours)
            let isMajor = abs(clamped.truncatingRemainder(dividingBy: 2)) < epsilon
            let isEnd = abs(clamped - totalHours) < epsilon
            let shouldLabel = isMajor && clamped <= 24 + epsilon && !isEnd
            let label = shouldLabel ? String(format: "%.0f", clamped) : ""
            let fraction = totalHours == 0 ? 0 : clamped / totalHours

            if !marks.contains(where: { abs($0.value - clamped) < epsilon }) {
                marks.append(TickMark(value: clamped,
                                      fraction: fraction,
                                      label: label,
                                      isMajor: isMajor))
            }

            current += step
        }

        if !marks.contains(where: { abs($0.value - totalHours) < epsilon }) {
            let isMajor = abs(totalHours.truncatingRemainder(dividingBy: 2)) < epsilon
            marks.append(TickMark(value: totalHours,
                                  fraction: 1,
                                  label: "",
                                  isMajor: isMajor))
        } else {
            marks = marks.map { tick in
                guard abs(tick.value - totalHours) < epsilon else { return tick }
                let isMajor = abs(totalHours.truncatingRemainder(dividingBy: 2)) < epsilon
                return TickMark(value: totalHours,
                                fraction: 1,
                                label: "",
                                isMajor: isMajor)
            }
        }

        marks.sort { $0.value < $1.value }
        return marks
    }

    struct TickMark: Hashable {
        let value: Double
        let fraction: Double
        let label: String
        let isMajor: Bool

        var length: CGFloat {
            isMajor ? 12 : 6
        }
    }
}

#Preview {
    BiologicalClockDial(state: .init(dayIndex: 1, offsetWithinDay: 7200, dayLength: 89640))
}
