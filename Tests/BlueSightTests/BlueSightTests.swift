import CoreGraphics
import Foundation
import Testing
@testable import BlueSight

private func packet(_ values: Float32...) -> Data {
    values.withUnsafeBytes { Data($0) }
}

@Test func parsesYawAndPitch() throws {
    let aiming = try #require(parseAiming(packet(10, -20)))
    #expect(aiming.yaw == 10)
    #expect(aiming.pitch == -20)
}

@Test func parsesUnalignedSlice() throws {
    let data = Data([0]) + packet(10, -20)
    let aiming = try #require(parseAiming(data.dropFirst()))
    #expect(aiming.yaw == 10)
    #expect(aiming.pitch == -20)
}

@Test func ignoresTrailingBytes() {
    #expect(parseAiming(packet(10, -20) + Data([1])) != nil)
}

@Test func rejectsBadPackets() {
    #expect(parseAiming(Data()) == nil)
    #expect(parseAiming(packet(10, -20).dropLast()) == nil)
    #expect(parseAiming(packet(.nan, 0)) == nil)
    #expect(parseAiming(packet(0, .infinity)) == nil)
}

@Test func isRunningFollowsConnection() {
    let sight = BlueSight()
    #expect(!sight.isRunning)
    sight.reportAiming(yaw: 0, pitch: 0)
    #expect(sight.isRunning)
    sight.reportDisconnected()
    #expect(!sight.isRunning)
}

@Test func mapsAnglesToLocation() {
    let sight = BlueSight()
    // Positive yaw is left; x is positive to the right.
    sight.reportAiming(yaw: -45, pitch: 30)
    #expect(abs(sight.location.x - 1) < 1e-6)
    #expect(abs(sight.location.y - 1) < 1e-6)
}
