import Foundation
import HealthKit

/// SessionBuilder reconstructs sleep sessions from HealthKit samples
/// This is the core engine for Whoop/Athlytic/Bevel-like sleep analysis
final class SleepSessionBuilder {
    
    // MARK: - Configuration
    
    private let maxGapBetweenSamples: TimeInterval = 30 * 60 // 30 minutes
    private let minimumSessionDuration: TimeInterval = 90 * 60 // 90 minutes (exclude short naps)
    private let calendar = Calendar.current
    
    // MARK: - Public API
    
    /// Build sleep sessions from HealthKit samples over a date range
    func buildSessions(from samples: [HKCategorySample], 
                      startDate: Date, 
                      endDate: Date) -> [SleepSession] {
        
        print("🛌 Building sleep sessions from \(samples.count) samples")
        
        // 1. Filter and validate samples
        let validSamples = filterValidSamples(samples, startDate: startDate, endDate: endDate)
        print("🛌 Valid samples: \(validSamples.count)")
        
        // 2. Group samples into contiguous intervals
        let intervals = groupIntoSleepIntervals(validSamples)
        print("🛌 Sleep intervals: \(intervals.count)")
        
        // 3. Reconstruct sessions from intervals
        let sessions = reconstructSessions(from: intervals)
        print("🛌 Reconstructed sessions: \(sessions.count)")
        
        // 4. Calculate advanced metrics for each session
        let finalSessions = sessions.map { calculateAdvancedMetrics(for: $0) }
        print("🛌 Final sessions with metrics: \(finalSessions.count)")
        
        return finalSessions
    }
    
    /// Build daily sleep summary from sessions
    func buildDailySummary(for date: Date, sessions: [SleepSession]) -> DailySleepSummary {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        
        print("🛌 Building daily summary for \(date) (dayStart: \(dayStart), dayEnd: \(dayEnd))")
        print("🛌 Total sessions available: \(sessions.count)")
        
        // Find sessions that overlap with this day
        let daySessions = sessions.filter { session in
            session.startDate < dayEnd && session.endDate > dayStart
        }
        
        print("🛌 Sessions overlapping with day: \(daySessions.count)")
        
        // Primary session is the longest one
        let primarySession = daySessions.max { $0.duration < $1.duration }
        
        // Aggregate metrics
        let totalDuration = daySessions.reduce(0) { $0 + $1.duration }
        let totalWakeEvents = daySessions.reduce(0) { $0 + $1.wakeEvents }
        
        let averageEfficiency = daySessions.isEmpty ? 0 : 
            daySessions.reduce(0) { $0 + $1.efficiency } / Double(daySessions.count)
        
        // Calculate bedtime and wake time from primary session
        let bedtime = primarySession?.startDate
        let wakeTime = primarySession?.endDate
        
        let summary = DailySleepSummary(
            date: dayStart,
            primarySession: primarySession,
            totalDuration: totalDuration,
            averageEfficiency: averageEfficiency,
            totalWakeEvents: totalWakeEvents,
            bedtime: bedtime,
            wakeTime: wakeTime
        )
        
        print("🛌 Daily summary: \(summary.hasData ? "Has data" : "No data"), duration: \(summary.durationHours)h")
        
        return summary
    }
    
    // MARK: - Private Implementation
    
    private func filterValidSamples(_ samples: [HKCategorySample], 
                                  startDate: Date, 
                                  endDate: Date) -> [HKCategorySample] {
        print("🛌 Filtering \(samples.count) samples from \(startDate) to \(endDate)")
        
        let validSamples = samples.filter { sample in
            // Basic validation
            guard sample.endDate > sample.startDate else { 
                print("🛌 Invalid sample: endDate <= startDate")
                return false 
            }
            guard sample.endDate <= Date() else { 
                print("🛌 Future sample rejected: \(sample.endDate)")
                return false 
            } // No future samples
            
            // Date range filter
            guard sample.startDate < endDate && sample.endDate > startDate else { 
                print("🛌 Sample outside date range: \(sample.startDate) - \(sample.endDate)")
                return false 
            }
            
            // Only include sleep-related categories
            let sleepCategories: [HKCategoryValueSleepAnalysis] = [
                .inBed,
                .asleepUnspecified,
                .asleepCore,
                .asleepDeep,
                .asleepREM,
                .awake
            ]
            
            let isValid = sleepCategories.contains { sample.value == $0.rawValue }
            if !isValid {
                print("🛌 Non-sleep sample rejected: \(sample.value)")
            }
            return isValid
        }
        
        print("🛌 Valid samples after filtering: \(validSamples.count)")
        return validSamples
    }
    
    private func groupIntoSleepIntervals(_ samples: [HKCategorySample]) -> [SleepInterval] {
        // Sort samples by start time
        let sortedSamples = samples.sorted { $0.startDate < $1.startDate }
        print("🛌 Grouping \(sortedSamples.count) sorted samples into intervals")
        
        var intervals: [SleepInterval] = []
        var currentInterval: SleepInterval?
        
        for sample in sortedSamples {
            if let current = currentInterval {
                // Check if this sample continues the current interval
                let gap = sample.startDate.timeIntervalSince(current.endDate)
                if gap <= maxGapBetweenSamples {
                    // Continue current interval
                    currentInterval = SleepInterval(
                        startDate: current.startDate,
                        endDate: max(current.endDate, sample.endDate),
                        samples: current.samples + [sample]
                    )
                    print("🛌 Extended interval: gap \(gap/60)min")
                } else {
                    // Start new interval
                    intervals.append(current)
                    currentInterval = SleepInterval(
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        samples: [sample]
                    )
                    print("🛌 New interval: gap \(gap/60)min > \(maxGapBetweenSamples/60)min")
                }
            } else {
                // Start first interval
                currentInterval = SleepInterval(
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    samples: [sample]
                )
                print("🛌 First interval started")
            }
        }
        
        // Add final interval
        if let current = currentInterval {
            intervals.append(current)
        }
        
        print("🛌 Created \(intervals.count) intervals")
        return intervals
    }
    
    private func reconstructSessions(from intervals: [SleepInterval]) -> [SleepSession] {
        print("🛌 Reconstructing sessions from \(intervals.count) intervals")
        
        return intervals.compactMap { interval in
            print("🛌 Processing interval: \(interval.duration/3600)h with \(interval.samples.count) samples")
            
            // Filter out short intervals (likely naps)
            guard interval.duration >= minimumSessionDuration else { 
                print("🛌 Interval too short: \(interval.duration/3600)h < \(minimumSessionDuration/3600)h")
                return nil 
            }
            
            // Find session boundaries (first inBed to last inBed)
            let inBedSamples = interval.samples.filter { 
                $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue 
            }
            
            guard let firstInBed = inBedSamples.first,
                  let lastInBed = inBedSamples.last else { 
                print("🛌 No inBed samples found in interval")
                return nil 
            }
            
            let sessionStart = firstInBed.startDate
            let sessionEnd = lastInBed.endDate
            
            // Calculate sleep stages
            let stages = calculateSleepStages(from: interval.samples, 
                                            sessionStart: sessionStart, 
                                            sessionEnd: sessionEnd)
            
            // Count wake events
            let wakeEvents = countWakeEvents(in: interval.samples)
            
            // Calculate efficiency
            let efficiency = calculateEfficiency(stages: stages)
            
            // Determine source
            let source = determineSource(from: interval.samples)
            
            // Create basic metrics (will be enhanced later)
            let metrics = SleepMetrics(
                waso: 0, // Will be calculated in calculateAdvancedMetrics
                fragmentationIndex: 0,
                sleepLatency: 0,
                consistency: 1.0
            )
            
            let session = SleepSession(
                startDate: sessionStart,
                endDate: sessionEnd,
                duration: sessionEnd.timeIntervalSince(sessionStart),
                efficiency: efficiency,
                stages: stages,
                wakeEvents: wakeEvents,
                source: source,
                metrics: metrics
            )
            
            print("🛌 Created session: \(session.durationHours)h, efficiency: \(efficiency*100)%")
            return session
        }
    }
    
    private func calculateSleepStages(from samples: [HKCategorySample], 
                                    sessionStart: Date, 
                                    sessionEnd: Date) -> SleepStages {
        var core: TimeInterval = 0
        var deep: TimeInterval = 0
        var rem: TimeInterval = 0
        var awake: TimeInterval = 0
        
        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            
            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                core += duration
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deep += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                rem += duration
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awake += duration
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                // Distribute unspecified sleep proportionally
                let totalSpecified = core + deep + rem
                if totalSpecified > 0 {
                    let coreRatio = core / totalSpecified
                    let deepRatio = deep / totalSpecified
                    let remRatio = rem / totalSpecified
                    
                    core += duration * coreRatio
                    deep += duration * deepRatio
                    rem += duration * remRatio
                } else {
                    // If no specified stages, assume it's core sleep
                    core += duration
                }
            default:
                break
            }
        }
        
        return SleepStages(core: core, deep: deep, rem: rem, awake: awake)
    }
    
    private func countWakeEvents(in samples: [HKCategorySample]) -> Int {
        var wakeEventCount = 0
        var wasInSleep = false
        
        for sample in samples.sorted(by: { $0.startDate < $1.startDate }) {
            let isAwake = sample.value == HKCategoryValueSleepAnalysis.awake.rawValue
            let isAsleep = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ].contains(sample.value)
            
            if isAsleep {
                wasInSleep = true
            } else if isAwake && wasInSleep {
                wakeEventCount += 1
                wasInSleep = false
            }
        }
        
        return wakeEventCount
    }
    
    private func calculateEfficiency(stages: SleepStages) -> Double {
        let totalInBed = stages.totalInBed
        guard totalInBed > 0 else { return 0 }
        return stages.totalAsleep / totalInBed
    }
    
    private func determineSource(from samples: [HKCategorySample]) -> String {
        // Check for Apple Watch samples (typically more detailed)
        let hasDetailedStages = samples.contains { sample in
            [
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ].contains(sample.value)
        }
        
        if hasDetailedStages {
            return "Apple Watch"
        } else {
            return "iPhone/Manual"
        }
    }
    
    private func calculateAdvancedMetrics(for session: SleepSession) -> SleepSession {
        // Calculate WASO (Wake After Sleep Onset)
        let waso = calculateWASO(for: session)
        
        // Calculate fragmentation index
        let fragmentationIndex = session.wakeEvents > 0 ? 
            Double(session.wakeEvents) / session.durationHours : 0
        
        // Calculate sleep latency (time from inBed to first sleep)
        let sleepLatency = calculateSleepLatency(for: session)
        
        // Calculate consistency (placeholder - would need historical data)
        let consistency = 1.0
        
        let enhancedMetrics = SleepMetrics(
            waso: waso,
            fragmentationIndex: fragmentationIndex,
            sleepLatency: sleepLatency,
            consistency: consistency
        )
        
        return SleepSession(
            startDate: session.startDate,
            endDate: session.endDate,
            duration: session.duration,
            efficiency: session.efficiency,
            stages: session.stages,
            wakeEvents: session.wakeEvents,
            source: session.source,
            metrics: enhancedMetrics
        )
    }
    
    private func calculateWASO(for session: SleepSession) -> TimeInterval {
        // WASO is the total awake time after sleep onset
        // For now, we'll use the awake time from stages
        // In a more sophisticated implementation, you'd track the first sleep onset
        return session.stages.awake
    }
    
    private func calculateSleepLatency(for session: SleepSession) -> TimeInterval {
        // Sleep latency is time from going to bed to first sleep
        // This would require more detailed sample analysis
        // For now, estimate as 10% of total awake time
        return session.stages.awake * 0.1
    }
}

// MARK: - Supporting Types

private struct SleepInterval {
    let startDate: Date
    let endDate: Date
    let samples: [HKCategorySample]
    
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
}
