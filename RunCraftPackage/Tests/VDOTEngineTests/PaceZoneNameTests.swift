import Foundation
import Testing
@testable import VDOTEngine

@Suite("PaceZoneName + paceRange(for:vdot:)")
struct PaceZoneNameTests {

    // MARK: - Single-zone lookup matches the batch function

    @Test("paceRange(for:vdot:) returns the same range as paceZones(vdot:)[zone]",
          arguments: [
            (PaceZoneName.easy,       40.0),
            (PaceZoneName.marathon,   40.0),
            (PaceZoneName.threshold,  40.0),
            (PaceZoneName.interval,   40.0),
            (PaceZoneName.repetition, 40.0),
            (PaceZoneName.threshold,  30.82),  // anchor for low VDOT correction
            (PaceZoneName.interval,   50.0),
            (PaceZoneName.easy,       70.0),
          ] as [(PaceZoneName, Double)])
    func paceRange_matchesPaceZones(_ zone: PaceZoneName, _ vdot: Double) {
        let single = VDOTCalculator.paceRange(for: zone, vdot: vdot)
        let batch  = VDOTCalculator.paceZones(vdot: vdot)[zone]
        #expect(single.lower == batch.lower)
        #expect(single.upper == batch.upper)
    }

    // MARK: - Iteration via subscript

    @Test("All five zones reachable via subscript on PaceZones — used by PaceZonesSummaryCard ForEach")
    func subscript_coversAllZones() {
        let zones = VDOTCalculator.paceZones(vdot: 40)
        for zone in PaceZoneName.allCases {
            let range = zones[zone]
            #expect(range.lower > 0)
            #expect(range.upper >= range.lower)
        }
    }

    @Test("Ordering invariant — faster zones have lower sec/km than slower ones")
    func zoneOrdering() {
        let zones = VDOTCalculator.paceZones(vdot: 40)
        // E (slowest) > M > T > I > R (fastest); use the LOWER bound for comparison
        #expect(zones[.easy].lower       > zones[.marathon].lower)
        #expect(zones[.marathon].lower   > zones[.threshold].lower)
        #expect(zones[.threshold].lower  > zones[.interval].lower)
        #expect(zones[.interval].lower   > zones[.repetition].lower)
    }

    // MARK: - PaceZoneName surface

    @Test("PaceZoneName.allCases enumerates all 5 Jack Daniels zones")
    func allCases_count() {
        #expect(PaceZoneName.allCases.count == 5)
        let letters = Set(PaceZoneName.allCases.map(\.letter))
        #expect(letters == ["E", "M", "T", "I", "R"])
    }

    @Test("Display name is human-readable, not the raw enum case")
    func displayName_humanReadable() {
        #expect(PaceZoneName.easy.displayName       == "Easy")
        #expect(PaceZoneName.marathon.displayName   == "Marathon")
        #expect(PaceZoneName.threshold.displayName  == "Threshold")
        #expect(PaceZoneName.interval.displayName   == "Interval")
        #expect(PaceZoneName.repetition.displayName == "Repetition")
    }
}
