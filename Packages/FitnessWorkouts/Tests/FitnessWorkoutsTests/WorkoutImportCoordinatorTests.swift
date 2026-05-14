import Testing
import Foundation
@testable import FitnessWorkouts

@Suite("WorkoutImportCoordinator", .tags(.fast))
@MainActor
struct WorkoutImportCoordinatorTests {

    private func makeTempFileURL(extension ext: String = "json") -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).\(ext)")
    }

    @Test func handleIncomingFile_setsPendingImportText() throws {
        let sut = WorkoutImportCoordinator()
        let url = makeTempFileURL()
        let content = #"{"version":1,"workout":{"name":"X"}}"#
        try content.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        sut.handleIncomingFile(url)

        #expect(sut.pendingImportText == content)
    }

    @Test func handleIncomingFile_ignoresNonFileURLs() {
        let sut = WorkoutImportCoordinator()
        let httpsURL = URL(string: "https://example.com/workout.json")!

        sut.handleIncomingFile(httpsURL)

        #expect(sut.pendingImportText == nil)
    }

    @Test func handleIncomingFile_ignoresNonexistentPath() {
        let sut = WorkoutImportCoordinator()
        let bogus = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).json")

        sut.handleIncomingFile(bogus)

        #expect(sut.pendingImportText == nil)
    }

    @Test func handleIncomingFile_ignoresInvalidUTF8() throws {
        let sut = WorkoutImportCoordinator()
        let url = makeTempFileURL()
        // Bytes that don't form valid UTF-8 (continuation byte without start)
        let invalidUTF8 = Data([0xC3, 0x28, 0xA0, 0xA1])
        try invalidUTF8.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        sut.handleIncomingFile(url)

        #expect(sut.pendingImportText == nil)
    }

    @Test func clearPending_resetsState() throws {
        let sut = WorkoutImportCoordinator()
        let url = makeTempFileURL()
        try "hello".data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        sut.handleIncomingFile(url)
        #expect(sut.pendingImportText == "hello")

        sut.clearPending()

        #expect(sut.pendingImportText == nil)
    }

    @Test func handleIncomingFile_overwritesExistingPendingText() throws {
        let sut = WorkoutImportCoordinator()
        let url1 = makeTempFileURL()
        let url2 = makeTempFileURL()
        try "first".data(using: .utf8)!.write(to: url1)
        try "second".data(using: .utf8)!.write(to: url2)
        defer {
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        }

        sut.handleIncomingFile(url1)
        #expect(sut.pendingImportText == "first")
        sut.handleIncomingFile(url2)

        #expect(sut.pendingImportText == "second", "Second file must overwrite the first one's pending text.")
    }
}
