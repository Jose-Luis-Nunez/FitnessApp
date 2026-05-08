import Testing
import Foundation
@testable import FitnessProfile

@Suite("SBahnClassifier Tests", .tags(.fast))
struct SBahnClassifierTests {

    private let config = SBahnRouteConfiguration.standardBerlin

    // MARK: - east-direct (passes through Ostkreuz)

    @Test("S3 Erkner is east-direct")
    func s3Erkner_isEastDirect() {
        let cls = SBahnClassifier.classify(line: "S3", direction: "S Erkner Bhf", configuration: config)
        #expect(cls == .eastDirect)
    }

    @Test("S5 Strausberg is east-direct")
    func s5Strausberg_isEastDirect() {
        let cls = SBahnClassifier.classify(line: "S5", direction: "S Strausberg Nord", configuration: config)
        #expect(cls == .eastDirect)
    }

    @Test("S7 Ahrensfelde is east-direct")
    func s7Ahrensfelde_isEastDirect() {
        let cls = SBahnClassifier.classify(line: "S7", direction: "S Ahrensfelde Bhf (Berlin)", configuration: config)
        #expect(cls == .eastDirect)
    }

    @Test("S5 Hoppegarten is east-direct")
    func s5Hoppegarten_isEastDirect() {
        let cls = SBahnClassifier.classify(line: "S5", direction: "S Hoppegarten", configuration: config)
        #expect(cls == .eastDirect)
    }

    // MARK: - east-short@Warschauer (S9 bypass + explicit Warschauer terminus)

    @Test("S9 Flughafen BER is east-short@Warschauer (bypass case)")
    func s9BER_isEastShortWarschauer() {
        let cls = SBahnClassifier.classify(line: "S9", direction: "Flughafen BER", configuration: config)
        #expect(cls == .eastShortWarschauer)
    }

    @Test("S9 Schöneweide is east-short@Warschauer")
    func s9Schoeneweide_isEastShortWarschauer() {
        let cls = SBahnClassifier.classify(line: "S9", direction: "S Schöneweide Bhf", configuration: config)
        #expect(cls == .eastShortWarschauer)
    }

    @Test("Any line ending at Warschauer is east-short@Warschauer")
    func anyLineWarschauer_isEastShortWarschauer() {
        let cls = SBahnClassifier.classify(line: "S5", direction: "S+U Warschauer Str. (Berlin)", configuration: config)
        #expect(cls == .eastShortWarschauer)
    }

    // MARK: - east-short@Ostbahnhof (terminus)

    @Test("S7 Ostbahnhof is east-short@Ostbahnhof")
    func s7Ostbahnhof_isEastShortOstbahnhof() {
        let cls = SBahnClassifier.classify(line: "S7", direction: "S Ostbahnhof (Berlin)", configuration: config)
        #expect(cls == .eastShortOstbahnhof)
    }

    // MARK: - west (filtered)

    @Test("S5 Westkreuz is west")
    func s5Westkreuz_isWest() {
        let cls = SBahnClassifier.classify(line: "S5", direction: "S Westkreuz (Berlin)", configuration: config)
        #expect(cls == .west)
    }

    @Test("S3 Spandau is west")
    func s3Spandau_isWest() {
        let cls = SBahnClassifier.classify(line: "S3", direction: "S Spandau Bhf (Berlin)", configuration: config)
        #expect(cls == .west)
    }

    // MARK: - unknown (filtered)

    @Test("Unknown destination is unknown")
    func unknownDirection_isUnknown() {
        let cls = SBahnClassifier.classify(line: "S3", direction: "S Some Random Place", configuration: config)
        #expect(cls == .unknown)
    }

    // MARK: - transferOptions

    @Test("east-direct has no transfer options")
    func eastDirect_hasNoTransferOptions() {
        #expect(SBahnClassification.eastDirect.transferOptions.isEmpty)
        #expect(SBahnClassification.eastDirect.needsBridge == false)
    }

    @Test("east-short@Ostbahnhof offers only Ostbahnhof transfer")
    func eastShortOstbahnhof_offersOnlyOstbahnhof() {
        #expect(SBahnClassification.eastShortOstbahnhof.transferOptions == [.ostbahnhof])
        #expect(SBahnClassification.eastShortOstbahnhof.needsBridge)
    }

    @Test("east-short@Warschauer offers both transfers")
    func eastShortWarschauer_offersBoth() {
        #expect(SBahnClassification.eastShortWarschauer.transferOptions == [.ostbahnhof, .warschauer])
        #expect(SBahnClassification.eastShortWarschauer.needsBridge)
    }

    // MARK: - isEastDirectAtTransfer (bridge-pool eligibility)

    @Test("Bridge candidate that ends at Ostbahnhof is rejected")
    func bridgeCandidate_endingAtOstbahnhof_isRejected() {
        let ok = SBahnClassifier.isEastDirectAtTransfer(line: "S3", direction: "S Ostbahnhof (Berlin)", configuration: config)
        #expect(ok == false)
    }

    @Test("Bridge candidate going west is rejected")
    func bridgeCandidate_west_isRejected() {
        let ok = SBahnClassifier.isEastDirectAtTransfer(line: "S5", direction: "S Westkreuz (Berlin)", configuration: config)
        #expect(ok == false)
    }

    @Test("Bridge candidate to Erkner is accepted")
    func bridgeCandidate_toErkner_isAccepted() {
        let ok = SBahnClassifier.isEastDirectAtTransfer(line: "S3", direction: "S Erkner Bhf", configuration: config)
        #expect(ok == true)
    }
}
