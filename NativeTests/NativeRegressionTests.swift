import XCTest
@testable import NightwellMusic

private actor LyricsStub: LyricsService {
    let responses: [Lyrics]
    var calls = 0
    init(_ responses: [Lyrics]) { self.responses = responses }
    func fetchLyrics(_ id: String) async throws -> Lyrics { defer { calls += 1 }; return responses[min(calls, responses.count - 1)] }
    func count() -> Int { calls }
}
@MainActor final class NativeRegressionTests: XCTestCase {
    let origin = URL(string: "https://music.nightwell.fun/")!
    func track(_ id: String = "regression") -> Track { Track(id: id, title: "Song", artist: "Artist") }
    func waitForResult(_ model: NativeLyrics) async throws {
        for _ in 0..<100 {
            if model.value?.status == "found" { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Client stopped waiting before the lyrics search completed")
    }
    func testServerLoadingResponseIsPolledUntilFound() async throws {
        let stub = LyricsStub([Lyrics(status: "loading", retry_after: 5), Lyrics(status: "found", plain: "available again", synced: false)])
        let model = NativeLyrics(cacheEnabled: false, sleep: { _ in await Task.yield() })
        model.select(track(), api: stub, origin: origin, online: true)
        try await waitForResult(model)
        let count = await stub.count(); XCTAssertEqual(count, 2)
        XCTAssertEqual(model.value?.plain, "available again")
    }
    func testTemporaryProviderFailureIsRetried() async throws {
        let stub = LyricsStub([Lyrics(status: "unavailable", retry_after: 60), Lyrics(status: "found", lines: [.init(time: 10, text: "line")], synced: true)])
        let model = NativeLyrics(cacheEnabled: false, sleep: { _ in await Task.yield() })
        model.select(track(), api: stub, origin: origin, online: true)
        try await waitForResult(model)
        XCTAssertEqual(model.value?.synced, true)
        let count = await stub.count(); XCTAssertEqual(count, 2)
    }
    func testNewTrackCancelsPreviousLyrics() async throws {
        let first = LyricsStub([Lyrics(status: "loading", retry_after: 5)])
        let second = LyricsStub([Lyrics(status: "found", plain: "second")])
        let model = NativeLyrics(cacheEnabled: false)
        model.select(track("first"), api: first, origin: origin, online: true)
        try await Task.sleep(nanoseconds: 20_000_000)
        model.select(track("second"), api: second, origin: origin, online: true)
        try await waitForResult(model)
        XCTAssertEqual(model.trackID, "second"); XCTAssertEqual(model.value?.plain, "second")
    }
    func testPlayerQueueRetainsDownloadedLyricsMetadata() throws {
        let player = NativePlayer.shared
        defer { player.stop() }
        var saved = track("saved_snapshot"); saved._offline = true
        saved._offline_lyrics = Lyrics(status: "found", plain: "saved metadata", synced: false)
        player.prepare(["id": saved.id, "queue": [saved.dictionary], "account": "device"], origin: origin, cookies: [])
        let raw = try XCTUnwrap(player.snapshot()["queueTracks"] as? [[String: Any]])
        let decoded = try JSONDecoder().decode([Track].self, from: JSONSerialization.data(withJSONObject: raw))
        XCTAssertEqual(decoded.first?._offline_lyrics?.plain, "saved metadata")
    }
    func testLegacyDownloadedLyricsRemainAvailableWithoutLogin() async throws {
        let stub = LyricsStub([Lyrics(status: "not_found")])
        var saved = track("saved_song"); saved._offline = true
        saved._offline_lyrics = Lyrics(status: "found", plain: "saved on device", synced: false)
        let model = NativeLyrics(cacheEnabled: false)
        model.select(saved, api: stub, origin: origin, online: false)
        try await waitForResult(model)
        XCTAssertEqual(model.value?.plain, "saved on device")
        let calls = await stub.count(); XCTAssertEqual(calls, 0)
    }
    func testPlaybackMemoryKeepsPositionQueueAndModesWithinAccount() {
        let account = "test_" + UUID().uuidString
        defer { UserDefaults.standard.removeObject(forKey: PlaybackMemory.key(origin, account)) }
        PlaybackMemory(id: "second", tracks: [track("first"), track("second")], position: 87.5, repeatMode: 2, shuffle: true, wave: true).save(origin, account)
        let restored = PlaybackMemory.read(origin, account)
        XCTAssertEqual(restored?.position, 87.5); XCTAssertEqual(restored?.id, "second")
        XCTAssertEqual(restored?.tracks.map(\.id), ["first", "second"])
        XCTAssertEqual(restored?.repeatMode, 2); XCTAssertEqual(restored?.shuffle, true)
        XCTAssertNil(PlaybackMemory.read(origin, account + "_other"))
    }
    func testIncompleteDownloadCannotBecomeOfflineTrack() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("{\"error\":\"not an audio file\"}".utf8).write(to: file)
        let account = "test_" + UUID().uuidString
        XCTAssertThrowsError(try OfflineStore.saveDownloadedFile(file, track: track(), origin: origin, account: account))
        XCTAssertNil(OfflineStore.audio(origin: origin, account: account, id: "regression"))
    }
}
