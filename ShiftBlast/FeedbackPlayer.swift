import AVFoundation
import UIKit

@MainActor
final class FeedbackPlayer {
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let clearGenerator = UINotificationFeedbackGenerator()
    private var audioPlayer: AVAudioPlayer?

    init() {
        impactGenerator.prepare()
        clearGenerator.prepare()
        audioPlayer = makePopPlayer()
    }

    func impact() {
        impactGenerator.impactOccurred(intensity: 0.65)
        impactGenerator.prepare()
    }

    func clear() {
        clearGenerator.notificationOccurred(.success)
        clearGenerator.prepare()
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }

    private func makePopPlayer() -> AVAudioPlayer? {
        let sampleRate = 44_100
        let duration = 0.11
        let sampleCount = Int(Double(sampleRate) * duration)
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)

        for index in 0..<sampleCount {
            let t = Double(index) / Double(sampleRate)
            let envelope = exp(-38 * t)
            let crack = sin(2 * .pi * 1_240 * t) + 0.45 * sin(2 * .pi * 2_940 * t)
            samples.append(Int16(max(-1, min(1, crack * envelope)) * Double(Int16.max)))
        }

        let data = waveData(samples: samples, sampleRate: sampleRate)
        return try? AVAudioPlayer(data: data)
    }

    private func waveData(samples: [Int16], sampleRate: Int) -> Data {
        var data = Data()
        let byteRate = sampleRate * 2
        let blockAlign: UInt16 = 2
        let subchunk2Size = UInt32(samples.count * 2)
        let chunkSize = UInt32(36) + subchunk2Size

        data.append(contentsOf: "RIFF".utf8)
        data.appendLittleEndian(chunkSize)
        data.append(contentsOf: "WAVEfmt ".utf8)
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(byteRate))
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(UInt16(16))
        data.append(contentsOf: "data".utf8)
        data.appendLittleEndian(subchunk2Size)
        samples.forEach { data.appendLittleEndian($0) }
        return data
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
