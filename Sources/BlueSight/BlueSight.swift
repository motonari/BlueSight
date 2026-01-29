// The Swift Programming Language
// https://docs.swift.org/swift-book

import CoreBluetooth
import CoreGraphics
import Foundation
import Synchronization

class Point {
    private var previousTime: ContinuousClock.Instant?
    let coordinates = Mutex<CGPoint>(CGPoint())

    var location: CGPoint {
        return coordinates.withLock { coords in
            coords
        }
    }

    func gyroscope(x: CGFloat, y: CGFloat, z: CGFloat) {
        coordinates.withLock { coords in
            let currentTime = ContinuousClock.now
            if let previousTime = self.previousTime {
                let elapsedTime = previousTime.duration(to: currentTime) / .seconds(1)
                let deltaZ = 2 * tan(z * elapsedTime * CGFloat.pi / 180.0)
                let deltaY = 2 * tan(y * elapsedTime * CGFloat.pi / 180.0)

                coords.x = min(max(coords.x - deltaZ, -1.0), +1.0)
                coords.y = min(max(coords.y + deltaY, -1.0), +1.0)
            }
            previousTime = currentTime
        }
    }
}

public final class BlueSight: @unchecked Sendable {
    private var central: BlueSightCentral?
    private let currentPoint = Point()

    public init() {
    }

    public func start() {
        guard central == nil else {
            fatalError("Do not call start more than once.")
        }
        self.central = BlueSightCentral(observer: self)
    }

    public var location: CGPoint {
        self.currentPoint.location
    }
}

extension BlueSight: MeasurementsObserver {
    func reportGyroscopeMeasurements(x: CGFloat, y: CGFloat, z: CGFloat) {
        self.currentPoint.gyroscope(x: x, y: y, z: z)
    }
}
