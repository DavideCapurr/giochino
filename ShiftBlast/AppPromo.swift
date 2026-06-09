import SwiftUI
import UIKit

/// Central place for the "growth" links and copy: sharing a score and asking for a
/// review. Both are zero-cost user-acquisition levers — word of mouth and App Store
/// ranking — which matter even more than monetization while the user base is small.
enum AppPromo {
    /// Numeric App Store ID — the digits in `https://apps.apple.com/app/idXXXXXXXXX`.
    /// TODO: set this once the app is live so shares and the review prompt deep-link
    /// straight into the App Store. Until then we fall back to the public landing page.
    static let appStoreID: String? = nil

    /// Public landing page (GitHub Pages) — already live, works as a share target even
    /// before the App Store ID is known. It can redirect visitors to the store.
    static let landingURL = URL(string: "https://davidecapurr.github.io/giochino/")!

    /// Best available link to send someone who wants the game.
    static var storeURL: URL {
        if let appStoreID, let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)") {
            return url
        }
        return landingURL
    }

    /// Shareable, brag-worthy message for a finished run.
    static func shareMessage(score: Int, bestScore: Int) -> String {
        let isBest = score > 0 && score >= bestScore
        let opener = isBest
            ? "I just set my best score of \(score) in Shift Blast! 🏆"
            : "I scored \(score) in Shift Blast!"
        return "\(opener)\nThink you can beat me? \(storeURL.absoluteString)"
    }
}

/// Minimal SwiftUI wrapper around the system share sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
