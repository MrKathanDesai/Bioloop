import Foundation
import HealthKit

// MARK: - Simple Architecture Test

class ArchitectureTest {
    static let shared = ArchitectureTest()

    func runBasicTest() async {
        print("🧪 Starting Architecture Test...")

        // Test 1: HealthKit Manager
        print("📊 Testing HealthKit Manager...")
        let healthKitManager = await HealthKitManager.shared

        let isAvailable = HKHealthStore.isHealthDataAvailable()
        print("   ✅ HealthKit Available: \(isAvailable)")

        let dataAvailability = await healthKitManager.checkDataAvailability()
        print("   ✅ Data Availability: \(dataAvailability.isFullyAvailable)")
        print("   ✅ Has Permission: \(dataAvailability.hasHealthKitPermission)")
        print("   ✅ Has Apple Watch: \(dataAvailability.hasAppleWatchData)")

        // Test 2: Data Fetching (will fail without permissions, but tests the flow)
        print("📊 Testing Data Fetching...")
        do {
            let testDate = Date()
            let healthData = try await healthKitManager.fetchHealthData(for: testDate)
            print("   ✅ Data Fetched Successfully")
            print("   ✅ HRV: \(healthData.hrv ?? 0)")
            print("   ✅ RHR: \(healthData.restingHeartRate ?? 0)")
            print("   ✅ Sleep: \(healthData.sleepDuration ?? 0)h")
        } catch {
            print("   ⚠️ Data Fetch Failed (expected without permissions): \(error.localizedDescription)")
        }

        // Test 3: Calculator
        print("📊 Testing Health Calculator...")
        let calculator = HealthCalculator.shared

        // Create sample data
        let sampleData = HealthData(
            date: Date(),
            hrv: 45.0,
            restingHeartRate: 55.0,
            heartRate: 70.0,
            energyBurned: 400.0,
            sleepStart: nil,
            sleepEnd: nil,
            sleepDuration: 8.0,
            sleepEfficiency: 0.85,
            deepSleep: 2.0,
            remSleep: 1.5,
            wakeEvents: 1,
            workoutMinutes: 30.0
        )

        let score = calculator.calculateHealthScores(from: sampleData)
        print("   ✅ Recovery Score: \(score.recovery.value) (\(score.recovery.status))")
        print("   ✅ Sleep Score: \(score.sleep.value) (\(score.sleep.status))")
        print("   ✅ Strain Score: \(score.strain.value) (\(score.strain.status))")
        print("   ✅ Stress Score: \(score.stress.value) (\(score.stress.status))")

        // Test 4: Data Manager
        print("📊 Testing Data Manager...")
        let dataManager = await DataManager.shared

        // Test journal entry
        let journalEntry = JournalEntry(
            date: Date(),
            title: "Test Entry",
            content: "Architecture test",
            mood: 4,
            factors: ["Sleep", "Exercise"]
        )
        await dataManager.saveJournalEntry(journalEntry)
        print("   ✅ Journal Entry Saved")

        // Test async data loading
        do {
            let testDate = Date()
            let score = try await dataManager.fetchHealthData(for: testDate)
            print("   ✅ Async Data Loading: Recovery \(score.recovery.value)")
        } catch {
            print("   ⚠️ Async Data Loading: Failed (\(error.localizedDescription))")
        }

        let entries = await dataManager.getJournalEntries(for: Date())
        print("   ✅ Retrieved \(entries.count) journal entries")

        print("🎉 Architecture Test Complete!")
        print("💡 To test with real data: Grant HealthKit permissions and run again")
    }

    func testDateRanges() {
        print("📅 Testing Date Range Calculations...")

        let calendar = Calendar.current
        let testDate = Date()

        // Test startOfDay calculation
        let startOfDay = calendar.startOfDay(for: testDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        print("   📅 Test Date: \(testDate)")
        print("   📅 Start of Day: \(startOfDay)")
        print("   📅 End of Day: \(endOfDay)")
        print("   📅 Range: \(startOfDay)...\(endOfDay)")

        // Test if range makes sense
        let hoursInRange = endOfDay.timeIntervalSince(startOfDay) / 3600
        print("   📅 Hours in range: \(hoursInRange) (should be 24)")

        if abs(hoursInRange - 24) < 0.1 {
            print("   ✅ Date range calculation is correct")
        } else {
            print("   ❌ Date range calculation is wrong")
        }
    }
}

// MARK: - Quick Test Runner

func runArchitectureTests() async {
    print("🚀 Running Bioloop Architecture Tests...")
    print("=====================================")

    // Test date ranges first
    let testInstance = ArchitectureTest.shared
    testInstance.testDateRanges()
    print("")

    // Run full architecture test
    await testInstance.runBasicTest()

    print("=====================================")
    print("🏁 Tests Complete!")
}
