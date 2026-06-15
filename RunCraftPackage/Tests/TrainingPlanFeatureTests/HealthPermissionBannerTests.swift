import HealthKitClient
import Testing
@testable import TrainingPlanFeature

@Suite("TrainingPlan — health permission lost gating")
struct HealthPermissionBannerTests {

    @Test(".needsRequest with a prior synced workout is reported as lost")
    func needsRequest_withSyncedWorkout_isLost() {
        #expect(TrainingPlan.healthPermissionLost(hasSyncedBefore: true, status: .needsRequest))
    }

    @Test(".needsRequest with no prior synced workout is not alarming")
    func needsRequest_withoutSyncedWorkout_isNotLost() {
        #expect(!TrainingPlan.healthPermissionLost(hasSyncedBefore: false, status: .needsRequest))
    }

    @Test(".authorized is never reported as lost, regardless of sync history")
    func authorized_isNeverLost() {
        #expect(!TrainingPlan.healthPermissionLost(hasSyncedBefore: true, status: .authorized))
        #expect(!TrainingPlan.healthPermissionLost(hasSyncedBefore: false, status: .authorized))
    }

    @Test(".unknown is never reported as lost")
    func unknown_isNeverLost() {
        #expect(!TrainingPlan.healthPermissionLost(hasSyncedBefore: true, status: .unknown))
    }
}
