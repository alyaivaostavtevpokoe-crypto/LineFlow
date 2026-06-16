//
//  ColorWheelView.swift
//  LineFlow
//
//  Created by macbook Алиса on 20/5/26.
//

import SwiftUI

struct ColorWheelView: View {
    @Binding var hue: Double
    @Binding var saturation: Double
    @Binding var brightness: Double

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )

            let outerRadius = size * 0.46
            let ringWidth = size * 0.13
            let innerRadius = outerRadius - ringWidth - size * 0.055

            ZStack {
                hueRing(
                    outerRadius: outerRadius,
                    ringWidth: ringWidth
                )

                innerColorCircle(radius: innerRadius)

                hueMarker(
                    outerRadius: outerRadius,
                    color: Color(hue: hue, saturation: 1, brightness: 1)
                )

                saturationBrightnessMarker(innerRadius: innerRadius)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleTouch(
                            point: value.location,
                            center: center,
                            outerRadius: outerRadius,
                            ringWidth: ringWidth,
                            innerRadius: innerRadius
                        )
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Внешнее кольцо

    private func hueRing(
        outerRadius: CGFloat,
        ringWidth: CGFloat
    ) -> some View {
        ZStack {
            ForEach(0..<360, id: \.self) { degree in
                let angleProgress = Double(degree) / 360.0

                // Инвертируем hue:
                // справа красный,
                // дальше по часовой: розовый, фиолетовый, синий, голубой,
                // зеленый, желтый, оранжевый.
                let hueValue = normalizedHue(1.0 - angleProgress)

                Circle()
                    .trim(
                        from: CGFloat(degree) / 360.0,
                        to: CGFloat(degree + 1) / 360.0
                    )
                    .stroke(
                        Color(
                            hue: hueValue,
                            saturation: 1.0,
                            brightness: 1.0
                        ),
                        style: StrokeStyle(
                            lineWidth: ringWidth,
                            lineCap: .butt
                        )
                    )
            }
        }
        .frame(width: outerRadius * 2, height: outerRadius * 2)
    }

    // MARK: - Центральный круг

    private func innerColorCircle(radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(hue: hue, saturation: 1, brightness: 1))

            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: .white.opacity(0.78), location: 0.18),
                            .init(color: .white.opacity(0.28), location: 0.48),
                            .init(color: .white.opacity(0.0), location: 0.78)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.0), location: 0.0),
                            .init(color: .black.opacity(0.18), location: 0.38),
                            .init(color: .black.opacity(0.68), location: 0.76),
                            .init(color: .black, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Circle()
                .stroke(.white.opacity(0.65), lineWidth: 1.4)
        }
        .frame(width: radius * 2, height: radius * 2)
        .clipShape(Circle())
    }

    // MARK: - Маркеры

    private func hueMarker(
        outerRadius: CGFloat,
        color: Color
    ) -> some View {
        // Инверсия относительно hueRing:
        // hue 0 / 1 находится справа.
        // При уменьшении hue маркер идет по часовой.
        let angle = CGFloat(1.0 - hue) * 2 * CGFloat.pi

        let x = cos(angle) * outerRadius
        let y = sin(angle) * outerRadius

        return Circle()
            .fill(color)
            .overlay {
                Circle()
                    .stroke(.white, lineWidth: 2.5)
            }
            .shadow(color: .black.opacity(0.45), radius: 5, x: 0, y: 3)
            .frame(width: 54, height: 54)
            .offset(x: x, y: y)
    }

    private func saturationBrightnessMarker(
        innerRadius: CGFloat
    ) -> some View {
        let x = (saturation - 0.5) * 2 * innerRadius
        let y = (0.5 - brightness) * 2 * innerRadius

        return Circle()
            .stroke(.white, lineWidth: 2.5)
            .background {
                Circle()
                    .fill(Color.white.opacity(0.12))
            }
            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            .frame(width: 34, height: 34)
            .offset(x: x, y: y)
    }

    // MARK: - Обработка касания

    private func handleTouch(
        point: CGPoint,
        center: CGPoint,
        outerRadius: CGFloat,
        ringWidth: CGFloat,
        innerRadius: CGFloat
    ) {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        let ringInnerRadius = outerRadius - ringWidth / 2
        let ringOuterRadius = outerRadius + ringWidth / 2

        if distance >= ringInnerRadius && distance <= ringOuterRadius {
            hue = hueFromPoint(dx: dx, dy: dy)
            return
        }

        if distance <= innerRadius {
            saturation = saturationFromPoint(dx: dx, innerRadius: innerRadius)
            brightness = brightnessFromPoint(dy: dy, innerRadius: innerRadius)
        }
    }

    private func hueFromPoint(dx: CGFloat, dy: CGFloat) -> Double {
        var angle = atan2(dy, dx)

        if angle < 0 {
            angle += 2 * CGFloat.pi
        }

        let angleProgress = Double(angle / (2 * CGFloat.pi))

        // Инверсия направления:
        // справа = красный,
        // по часовой = розовый, фиолетовый, синий, голубой, зеленый, желтый, оранжевый.
        return normalizedHue(1.0 - angleProgress)
    }

    private func saturationFromPoint(dx: CGFloat, innerRadius: CGFloat) -> Double {
        let value = (dx / innerRadius + 1) / 2
        return min(1, max(0, Double(value)))
    }

    private func brightnessFromPoint(dy: CGFloat, innerRadius: CGFloat) -> Double {
        let value = 1 - ((dy / innerRadius + 1) / 2)
        return min(1, max(0, Double(value)))
    }

    private func normalizedHue(_ value: Double) -> Double {
        var result = value

        while result < 0 {
            result += 1
        }

        while result > 1 {
            result -= 1
        }

        return result
    }
}
