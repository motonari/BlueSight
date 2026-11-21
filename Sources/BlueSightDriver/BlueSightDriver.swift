import ArgumentParser
import BlueSight

@main
struct BlueSightDriver: AsyncParsableCommand {
    mutating func run() async throws {
        let blueSight = BlueSight()
        blueSight.start()

        while true {
            print(blueSight.location)
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}
