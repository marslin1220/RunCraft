import Testing
import VDOTEngine

@Suite("VDOTCalculator")
struct VDOTCalculatorTests {

    // Reference values from Jack Daniels Running Formula 3rd ed.
    @Test("5K 25:00 → VDOT ≈ 40")
    func vdotFrom5K25min() {
        let vdot = VDOTCalculator.vdot(distanceMeters: 5000, timeSeconds: 25 * 60)
        #expect(abs(vdot - 40) < 2, "Expected VDOT ≈ 40, got \(vdot)")
    }

    @Test("5K 30:00 → VDOT ≈ 31")
    func vdotFrom5K30min() {
        let vdot = VDOTCalculator.vdot(distanceMeters: 5000, timeSeconds: 30 * 60)
        #expect(abs(vdot - 31) < 2, "Expected VDOT ≈ 31, got \(vdot)")
    }

    @Test("10K 48:00 → VDOT ≈ 42")
    func vdotFrom10K48min() {
        let vdot = VDOTCalculator.vdot(distanceMeters: 10_000, timeSeconds: 48 * 60)
        #expect(abs(vdot - 42) < 2, "Expected VDOT ≈ 42, got \(vdot)")
    }

    @Test("VDOT clamped at 30 minimum")
    func vdotMinClamped() {
        let vdot = VDOTCalculator.vdot(distanceMeters: 5000, timeSeconds: 60 * 60)
        #expect(vdot >= 30, "VDOT should be at least 30")
    }

    @Test("VDOT clamped at 85 maximum")
    func vdotMaxClamped() {
        let vdot = VDOTCalculator.vdot(distanceMeters: 5000, timeSeconds: 12 * 60)
        #expect(vdot <= 85, "VDOT should be at most 85")
    }

    // Pace zone ordering checks (faster zones should have lower sec/km)
    @Test("Pace zones ordered correctly for VDOT 40")
    func paceZonesOrderedVDOT40() {
        let zones = VDOTCalculator.paceZones(vdot: 40)
        #expect(zones.easy.lower > zones.marathon.lower, "Easy should be slower than Marathon")
        #expect(zones.marathon.lower > zones.threshold.lower, "Marathon should be slower than Threshold")
        #expect(zones.threshold.lower > zones.interval.lower, "Threshold should be slower than Interval")
        #expect(zones.interval.lower > zones.repetition.lower, "Interval should be slower than Repetition")
    }

    @Test("Pace zones ordering holds across VDOT range")
    func paceZonesConsistentAcrossRange() {
        for vdot in stride(from: 30.0, through: 85.0, by: 5.0) {
            let zones = VDOTCalculator.paceZones(vdot: vdot)
            #expect(zones.easy.lower > zones.threshold.lower,
                    "Easy should be slower than Threshold for VDOT \(vdot)")
            #expect(zones.threshold.lower > zones.repetition.lower,
                    "Threshold should be slower than Repetition for VDOT \(vdot)")
        }
    }

    @Test("Easy pace range has non-zero width")
    func easyPaceRangeNonZero() {
        let zones = VDOTCalculator.paceZones(vdot: 40)
        #expect(zones.easy.upper > zones.easy.lower + 10,
                "Easy pace range should span at least 10 sec/km")
    }

    @Test("PaceRange formatted output is non-empty")
    func paceRangeFormatted() {
        let zones = VDOTCalculator.paceZones(vdot: 50)
        #expect(!zones.easy.formatted().isEmpty)
        #expect(!zones.threshold.formatted().isEmpty)
    }
}
