import Foundation

/// Persists security-scoped bookmarks for folders the user grants access to
/// during onboarding (typically `~/.claude` and `~/.codex`).
///
/// Each persisted bookmark is keyed by an opaque slug we assign at grant time.
/// On launch, `resolveAll()` materialises every saved bookmark into a `Resolved`
/// handle the rest of the relay can use. The handle holds a security-scoped
/// access claim until `stopAccessing()` is called.
@MainActor
final class BookmarkStore {
    struct Entry: Codable, Equatable {
        var slug: String
        var data: Data
    }

    final class Resolved {
        let slug: String
        let url: URL
        private var didStartAccess: Bool

        init(slug: String, url: URL, didStartAccess: Bool) {
            self.slug = slug
            self.url = url
            self.didStartAccess = didStartAccess
        }

        func stopAccessing() {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
                didStartAccess = false
            }
        }

        deinit {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    private let defaults: UserDefaults
    private let key = "shiftblast.relay.bookmarks.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var entries: [Entry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    func save(slug: String, url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        var current = entries.filter { $0.slug != slug }
        current.append(Entry(slug: slug, data: bookmark))
        let encoded = try JSONEncoder().encode(current)
        defaults.set(encoded, forKey: key)
    }

    func remove(slug: String) {
        let current = entries.filter { $0.slug != slug }
        if let encoded = try? JSONEncoder().encode(current) {
            defaults.set(encoded, forKey: key)
        }
    }

    func resolveAll() -> [Resolved] {
        var out: [Resolved] = []
        for entry in entries {
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: entry.data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else {
                continue
            }
            let started = url.startAccessingSecurityScopedResource()
            out.append(Resolved(slug: entry.slug, url: url, didStartAccess: started))
        }
        return out
    }
}
