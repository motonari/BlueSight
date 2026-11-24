// C functions that Unity calls through DllImport. Call them from Unity's main thread.

// On tvOS, Unity compiles these sources into its own module, so there is nothing to import.
#if canImport(BlueSight)
import BlueSight
#endif

private let sight = BlueSight()
nonisolated(unsafe) private var started = false

/// Starts looking for the controller. Safe to call again, because the Unity Editor can keep
/// the library loaded between Play sessions.
@_cdecl("BlueSight_Start")
public func blueSightStart() {
    guard !started else { return }
    started = true
    sight.start()
}

/// Writes the latest aim (-1...+1, right and up positive).
/// Returns 1 while aiming data is arriving, otherwise 0.
@_cdecl("BlueSight_Read")
public func blueSightRead(_ x: UnsafeMutablePointer<Float>, _ y: UnsafeMutablePointer<Float>) -> Int32 {
    let location = sight.location
    x.pointee = Float(location.x)
    y.pointee = Float(location.y)
    return sight.isRunning ? 1 : 0
}
