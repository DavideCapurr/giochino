import Foundation

struct GameStore {
    private let fileName = "shift-blast-state.json"

    private var fileURL: URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return directory.appendingPathComponent(fileName)
    }

    func load() -> GameState? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return try? JSONDecoder().decode(GameState.self, from: data)
    }

    func save(_ state: GameState) {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Unable to save Shift Blast state: \(error)")
        }
    }
}
