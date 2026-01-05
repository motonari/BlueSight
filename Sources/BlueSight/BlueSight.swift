// The Swift Programming Language
// https://docs.swift.org/swift-book

import CoreBluetooth
import CoreGraphics
import Foundation

actor Point {
    private var previousTime: ContinuousClock.Instant?
    var point = CGPoint()

    func gyroscope(x: CGFloat, y: CGFloat, z: CGFloat) {
        let currentTime = ContinuousClock.now
        if let previousTime = self.previousTime {
            let elapsedTime = previousTime.duration(to: currentTime) / .seconds(1)

            let deltaZ = 2 * tan(z * elapsedTime * CGFloat.pi / 180.0)
            let deltaY = 2 * tan(y * elapsedTime * CGFloat.pi / 180.0)

            point.x = min(max(point.x - deltaZ, -1.0), +1.0)
            point.y = min(max(point.y + deltaY, -1.0), +1.0)

        }
        previousTime = currentTime
    }
}

public final class BlueSight: @unchecked Sendable, MeasurementsObserver {
    private let central = BlueSightCentral()
    private let currentPoint = Point()

    public init() {
        central.measurementsObserver = self
    }

    public var point: CGPoint {
        get async {
            await self.currentPoint.point
        }
    }

    nonisolated func gyroscope(x: CGFloat, y: CGFloat, z: CGFloat) {
        let point = self.currentPoint
        Task {
            await point.gyroscope(x: x, y: y, z: z)
        }
    }
}
