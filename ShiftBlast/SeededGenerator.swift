import Foundation

struct SeededGenerator: RandomNumberGenerator, Codable, Equatable {
    private(set) var state: UInt64

    init(seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1_000_000) ^ UInt64.random(in: UInt64.min...UInt64.max)) {
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        guard !range.isEmpty else { return range.lowerBound }
        let distance = UInt64(range.upperBound - range.lowerBound)
        return range.lowerBound + Int(next() % distance)
    }

    mutating func nextBool(probability: Double) -> Bool {
        let clamped = max(0, min(1, probability))
        let sample = Double(next() % 10_000) / 10_000
        return sample < clamped
    }
}
