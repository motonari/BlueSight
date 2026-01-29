import ArgumentParser
import BlueSight

@main
struct BlueSightDriver: AsyncParsableCommand {
    mutating func run() async throws {
        let blueSight = BlueSight()

        while true {
            print(blueSight.location)
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
