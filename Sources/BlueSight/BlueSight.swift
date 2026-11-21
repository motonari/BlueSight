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

    func updateWithAiming(yaw: CGFloat, pitch: CGFloat) {
        coordinates.withLock { coords in
            let yawRad = yaw * CGFloat.pi / 180.0 
            let pitchRad = pitch * CGFloat.pi / 180.0

            let yawMax = tan(45.0 * CGFloat.pi / 180.0)
            let pitchMax = tan(30.0 * CGFloat.pi / 180.0)
            coords.x = -min(max(tan(yawRad) / yawMax, -1.0), +1.0)
            coords.y = min(max(tan(pitchRad) / pitchMax, -1.0), +1.0)
        }
    }
}

public final class BlueSight: @unchecked Sendable {
    private var central: BlueSightCentral?
    private let currentPoint = Point()
    private var running = false

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

    public var isRunning: Bool {
        running
    }
}

extension BlueSight: MeasurementsObserver {
    func reportAiming(yaw: CGFloat, pitch: CGFloat) {
        running = true
        self.currentPoint.updateWithAiming(yaw: yaw, pitch: pitch)
    }
}
