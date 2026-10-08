import Foundation
import PresenterCore

/// Fills an empty library with enough to present: a starter theme and its
/// overlays, four public-domain hymns, the welcome deck, and a service that
/// runs them. Everything has a fixed id, so running it twice adds nothing.
public enum DemoLibrary {
    public static let pack = StarterPack.cleanGeometric
    public static let serviceID = "demo.service.sunday"

    public struct Song: Sendable {
        public var id: String
        public var title: String
        public var lyrics: String
    }

    public static let songs: [Song] = [
        Song(id: "demo.song.amazing-grace", title: "Amazing Grace", lyrics: """
            Verse 1
            Amazing grace, how sweet the sound
            That saved a wretch like me
            I once was lost, but now am found
            Was blind, but now I see

            Verse 2
            'Twas grace that taught my heart to fear
            And grace my fears relieved
            How precious did that grace appear
            The hour I first believed

            Verse 3
            Through many dangers, toils and snares
            I have already come
            'Tis grace hath brought me safe thus far
            And grace will lead me home

            Verse 4
            When we've been there ten thousand years
            Bright shining as the sun
            We've no less days to sing God's praise
            Than when we'd first begun
            """),
        Song(id: "demo.song.holy-holy-holy", title: "Holy, Holy, Holy", lyrics: """
            Verse 1
            Holy, holy, holy! Lord God Almighty!
            Early in the morning our song shall rise to Thee
            Holy, holy, holy! Merciful and mighty!
            God in three persons, blessed Trinity!

            Verse 2
            Holy, holy, holy! All the saints adore Thee
            Casting down their golden crowns around the glassy sea
            Cherubim and seraphim falling down before Thee
            Which wert, and art, and evermore shalt be

            Verse 3
            Holy, holy, holy! Though the darkness hide Thee
            Though the eye of sinful man Thy glory may not see
            Only Thou art holy; there is none beside Thee
            Perfect in power, in love, and purity
            """),
        Song(id: "demo.song.it-is-well", title: "It Is Well with My Soul", lyrics: """
            Verse 1
            When peace like a river attendeth my way
            When sorrows like sea billows roll
            Whatever my lot, Thou hast taught me to say
            It is well, it is well with my soul

            Chorus
            It is well with my soul
            It is well, it is well with my soul

            Verse 2
            Though Satan should buffet, though trials should come
            Let this blest assurance control
            That Christ has regarded my helpless estate
            And hath shed His own blood for my soul

            Verse 3
            My sin, oh the bliss of this glorious thought
            My sin, not in part, but the whole
            Is nailed to the cross, and I bear it no more
            Praise the Lord, praise the Lord, O my soul
            """),
        Song(id: "demo.song.be-thou-my-vision", title: "Be Thou My Vision", lyrics: """
            Verse 1
            Be Thou my vision, O Lord of my heart
            Naught be all else to me, save that Thou art
            Thou my best thought, by day or by night
            Waking or sleeping, Thy presence my light

            Verse 2
            Be Thou my wisdom, and Thou my true word
            I ever with Thee and Thou with me, Lord
            Thou my great Father, I Thy true son
            Thou in me dwelling, and I with Thee one

            Verse 3
            High King of heaven, my victory won
            May I reach heaven's joys, O bright heaven's Sun
            Heart of my own heart, whatever befall
            Still be my vision, O Ruler of all
            """),
    ]

    public static func makeTheme() -> Theme {
        pack.makeTheme()
    }

    public static func makeSongs() -> [Presentation] {
        songs.map { song in
            var presentation = LyricTextImporter.makePresentation(
                song.lyrics, fallbackTitle: song.title, id: song.id, themeId: pack.themeID
            )
            presentation.name = song.title
            presentation.presentationKind = .song
            return presentation
        }
    }

    public static func makeService(serviceDate: String) -> Service {
        var items: [ServiceItem] = [
            ServiceItem(id: "\(serviceID).header.pre", itemKind: .header, name: "Pre-Service", refId: ""),
            ServiceItem(
                id: "\(serviceID).welcome", itemKind: .presentation,
                name: WelcomeDeck.presentationName, refId: WelcomeDeck.presentationID
            ),
            ServiceItem(id: "\(serviceID).header.worship", itemKind: .header, name: "Worship", refId: "", colorHex: "#3B82F6FF"),
        ]
        for song in songs {
            items.append(ServiceItem(id: "\(serviceID).\(song.id)", itemKind: .presentation, name: song.title, refId: song.id))
        }
        items.append(ServiceItem(id: "\(serviceID).header.message", itemKind: .header, name: "Message", refId: "", colorHex: "#FACC15FF"))
        return Service(id: serviceID, name: "Sunday Morning", serviceDate: serviceDate, items: items)
    }

    /// Adds whatever is missing. Returns the ids it created.
    @MainActor
    @discardableResult
    public static func install(into client: LibraryClient, serviceDate: String = HostPaths.todayISO()) async throws -> [String] {
        let index = try await client.settledSnapshot()
        var created: [String] = []

        let theme = makeTheme()
        if index.entry(id: theme.id) == nil {
            _ = try await client.create(theme).value
            created.append(theme.id)
        }
        for overlay in pack.makeOverlays() where index.entry(id: overlay.id) == nil {
            _ = try await client.create(overlay).value
            created.append(overlay.id)
        }
        if index.entry(id: WelcomeDeck.presentationID) == nil {
            _ = try await client.create(WelcomeDeck.makePresentation()).value
            created.append(WelcomeDeck.presentationID)
        }
        for presentation in makeSongs() where index.entry(id: presentation.id) == nil {
            _ = try await client.create(presentation).value
            created.append(presentation.id)
        }
        if index.entry(id: serviceID) == nil {
            _ = try await client.create(makeService(serviceDate: serviceDate)).value
            created.append(serviceID)
        }
        await client.settled()
        return created
    }
}
