import Foundation
import PresenterCore

/// What a fresh library gets on the Mac: every starter pack's theme and
/// overlays, and on the very first run the welcome deck in a Getting Started
/// service (AppModel.seedStarterThemes + finishOnboarding).
public enum StarterContent {

    /// Adds whatever is missing. Returns the ids it created.
    @MainActor
    @discardableResult
    public static func install(into client: LibraryClient, rootURL: URL, serviceDate: String = HostPaths.todayISO()) async throws -> [String] {
        let index = try await client.settledSnapshot()
        var created: [String] = []
        for pack in StarterPack.allCases {
            let theme = pack.makeTheme()
            if index.entry(id: theme.id) == nil {
                _ = try await client.create(theme).value
                created.append(theme.id)
            }
            for overlay in pack.makeOverlays() where index.entry(id: overlay.id) == nil {
                _ = try await client.create(overlay).value
                created.append(overlay.id)
            }
        }
        if Library.needsOnboarding(rootURL: rootURL, snapshot: index) {
            let batches = try await client.restoreWelcomeDeck(serviceDate: serviceDate)
            if !batches.isEmpty { created.append(WelcomeDeck.serviceID) }
            Library.markOnboarded(rootURL: rootURL)
        }
        await client.settled()
        return created
    }
}
