import Foundation
import HealthKit

// MARK: - Apple HealthKit Standards Health Score Calculator

class HealthCalculator {
    static let shared = HealthCalculator()

    private var baselineData = HealthBaseline()
    
    // MARK: - Apple Health Standards
    
    // VO2 Max ranges based on Apple Health and fitness standards
    private let vo2MaxRanges: [String: ClosedRange<Double>] = [
        "Poor": 0.0...29.9,
        "Fair": 30.0...39.9,
        "Good": 40.0...49.9,
        "Very Good": 50.0...59.9,
        "Excellent": 60.0...100.0
    ]
    
    // Resting Heart Rate ranges based on Apple Health standards
    private let rhrRanges: [String: ClosedRange<Double>] = [
        "Very Low": 0.0...39.9,
        "Excellent": 40.0...59.9,
        "Good": 60.0...79.9,
        "Fair": 80.0...99.9,
        "High": 100.0...200.0
    ]
    
    // HRV ranges based on Apple Health standards (varies by age/gender)
    private let hrvRanges: [String: ClosedRange<Double>] = [
        "Poor": 0.0...19.9,
        "Fair": 20.0...29.9,
        "Good": 30.0...49.9,
        "Very Good": 50.0...69.9,
        "Excellent": 70.0...200.0
    ]

    // MARK: - Score Calculations

    func calculateHealthScores(from data: HealthData) -> HealthScore {
        let recovery = calculateRecoveryScore(data)
        let sleep = calculateSleepScore(data)
        let strain = calculateStrainScore(data)
        let stress = calculateStressScore(data)

        let dataAvailability = DataAvailability(
            hasHealthKitPermission: true, // Assume we have permission if we got here
            hasAppleWatchData: data.hasRecoveryData || data.hasSleepData || data.hasStrainData,
            lastSyncDate: Date(),
            missingDataTypes: []
        )

        // Update baseline with new data
        baselineData.update(with: data)

        return HealthScore(
            recovery: recovery,
            sleep: sleep,
            strain: strain,
            stress: stress,
            date: data.date,
            dataAvailability: dataAvailability
        )
    }

    private func calculateRecoveryScore(_ data: HealthData) -> HealthScore.ScoreComponent {
        guard data.hasRecoveryData else {
            return HealthScore.ScoreComponent(
                value: 0,
                status: .unavailable,
                trend: nil,
                subMetrics: nil
            )
        }

        var score = 50.0 // Base score
        var subMetrics: [String: Double] = [:]

        // HRV contribution (40% weight) - Using Apple Health standards
        if let hrv = data.hrv {
            subMetrics["HRV"] = hrv
            
            // Use Apple Health standard ranges
            let hrvStatus = getHealthStatus(for: hrv, ranges: hrvRanges)
            switch hrvStatus {
            case "Excellent":
                score += 20
            case "Very Good":
                score += 15
            case "Good":
                score += 8
            case "Fair":
                score -= 5
            case "Poor":
                score -= 15
            default:
                break
            }
            
            // Also compare to personal baseline if available
            if let baseline = baselineData.hrvBaseline {
                let hrvRatio = hrv / baseline
                if hrvRatio > 1.1 {
                    score += 10 // Excellent recovery vs personal baseline
                } else if hrvRatio < 0.8 {
                    score -= 10 // Poor recovery vs personal baseline
                }
            }
        }

        // Resting Heart Rate contribution (30% weight) - Using Apple Health standards
        if let rhr = data.restingHeartRate {
            subMetrics["RHR"] = rhr
            
            // Use Apple Health standard ranges
            let rhrStatus = getHealthStatus(for: rhr, ranges: rhrRanges)
            switch rhrStatus {
            case "Excellent":
                score += 15
            case "Good":
                score += 8
            case "Fair":
                score -= 5
            case "High":
                score -= 15
            default:
                break
            }
            
            // Also compare to personal baseline if available
            if let baseline = baselineData.rhrBaseline {
                let rhrDiff = baseline - rhr
                if rhrDiff > 5 {
                    score += 10 // Much lower than baseline - great recovery
                } else if rhrDiff < -3 {
                    score -= 10 // Higher than baseline - poor recovery
                }
            }
        }

        // Sleep efficiency contribution (30% weight) - Using Apple Health standards
        if let efficiency = data.sleepEfficiency {
            subMetrics["Sleep Efficiency"] = efficiency * 100
            
            // Apple Health considers 85%+ as excellent sleep efficiency
            if efficiency >= 0.85 {
                score += 15
            } else if efficiency >= 0.75 {
                score += 8
            } else if efficiency < 0.65 {
                score -= 12
            }
        }

        // Clamp score between 0-100
        score = max(0, min(100, score))

        let status: HealthScore.ScoreStatus
        if score >= 75 {
            status = .optimal
        } else if score >= 50 {
            status = .moderate
        } else {
            status = .poor
        }

        return HealthScore.ScoreComponent(
            value: score,
            status: status,
            trend: nil,
            subMetrics: subMetrics
        )
    }
    
    // MARK: - Apple Health Status Helper
    
    private func getHealthStatus(for value: Double, ranges: [String: ClosedRange<Double>]) -> String {
        for (status, range) in ranges {
            if range.contains(value) {
                return status
            }
        }
        return "Unknown"
    }

    private func calculateSleepScore(_ data: HealthData) -> HealthScore.ScoreComponent {
        guard data.hasSleepData else {
            return HealthScore.ScoreComponent(
                value: 0,
                status: .unavailable,
                trend: nil,
                subMetrics: nil
            )
        }

        // Use comprehensive sleep session if available, otherwise fall back to basic metrics
        if let session = data.sleepSession {
            return calculateComprehensiveSleepScore(from: session)
        } else {
            return calculateBasicSleepScore(data)
        }
    }
    
    /// Comprehensive sleep scoring using Whoop/Athlytic/Bevel-like weighted approach
    private func calculateComprehensiveSleepScore(from session: SleepSession) -> HealthScore.ScoreComponent {
        var totalScore = 0.0
        var weightSum = 0.0
        var subMetrics: [String: Double] = [:]
        
        // 1. Duration vs goal (40% weight)
        let durationScore = calculateDurationScore(session.durationHours)
        totalScore += durationScore * 0.4
        weightSum += 0.4
        subMetrics["Duration"] = session.durationHours
        subMetrics["Duration Score"] = durationScore
        
        // 2. Efficiency (25% weight) - >85% is excellent
        let efficiencyScore = calculateEfficiencyScore(session.efficiency)
        totalScore += efficiencyScore * 0.25
        weightSum += 0.25
        subMetrics["Efficiency"] = session.efficiency * 100
        subMetrics["Efficiency Score"] = efficiencyScore
        
        // 3. REM percentage (15% weight) - optimal range 20-25%
        let remScore = calculateREMScore(session.stages.remPercentage)
        totalScore += remScore * 0.15
        weightSum += 0.15
        subMetrics["REM %"] = session.stages.remPercentage
        subMetrics["REM Score"] = remScore
        
        // 4. Deep sleep percentage (15% weight) - optimal range 15-20%
        let deepScore = calculateDeepScore(session.stages.deepPercentage)
        totalScore += deepScore * 0.15
        weightSum += 0.15
        subMetrics["Deep %"] = session.stages.deepPercentage
        subMetrics["Deep Score"] = deepScore
        
        // 5. Fragmentation penalty (5% weight) - lower is better
        let fragmentationScore = session.metrics.fragmentationScore
        totalScore += fragmentationScore * 0.05
        weightSum += 0.05
        subMetrics["Fragmentation"] = session.metrics.fragmentationIndex
        subMetrics["Fragmentation Score"] = fragmentationScore
        
        // 6. WASO penalty (additional)
        let wasoPenalty = calculateWASOPenalty(session.metrics.wasoMinutes)
        totalScore -= wasoPenalty
        subMetrics["WASO (min)"] = session.metrics.wasoMinutes
        subMetrics["WASO Penalty"] = wasoPenalty
        
        // Calculate final score
        let finalScore = max(0, min(100, totalScore / weightSum))
        
        let status: HealthScore.ScoreStatus
        if finalScore >= 80 {
            status = .optimal
        } else if finalScore >= 60 {
            status = .moderate
        } else {
            status = .poor
        }
        
        return HealthScore.ScoreComponent(
            value: finalScore,
            status: status,
            trend: nil,
            subMetrics: subMetrics
        )
    }
    
    /// Basic sleep scoring for legacy compatibility
    private func calculateBasicSleepScore(_ data: HealthData) -> HealthScore.ScoreComponent {
        var score = 50.0
        var subMetrics: [String: Double] = [:]

        // Sleep duration contribution (60% weight)
        if let duration = data.sleepDuration {
            subMetrics["Duration"] = duration
            let durationScore = calculateDurationScore(duration)
            score = durationScore
        }

        // Sleep efficiency contribution (40% weight)
        if let efficiency = data.sleepEfficiency {
            subMetrics["Efficiency"] = efficiency * 100
            let efficiencyScore = calculateEfficiencyScore(efficiency)
            score = (score * 0.6) + (efficiencyScore * 0.4)
        }

        // Wake events penalty
        if let wakeEvents = data.wakeEvents {
            subMetrics["Wake Events"] = Double(wakeEvents)
            let wakePenalty = Double(wakeEvents) * 2.0
            score = max(0, score - wakePenalty)
        }

        score = max(0, min(100, score))

        let status: HealthScore.ScoreStatus
        if score >= 80 {
            status = .optimal
        } else if score >= 60 {
            status = .moderate
        } else {
            status = .poor
        }

        return HealthScore.ScoreComponent(
            value: score,
            status: status,
            trend: nil,
            subMetrics: subMetrics
        )
    }
    
    // MARK: - Sleep Component Scoring
    
    private func calculateDurationScore(_ hours: Double) -> Double {
        // Optimal sleep duration: 7-9 hours
        if hours >= 8.5 && hours <= 9.5 {
            return 100 // Perfect
        } else if hours >= 7.5 && hours <= 8.5 {
            return 90 // Excellent
        } else if hours >= 7.0 && hours <= 7.5 {
            return 80 // Good
        } else if hours >= 6.5 && hours <= 7.0 {
            return 70 // Fair
        } else if hours >= 6.0 && hours <= 6.5 {
            return 60 // Poor
        } else if hours >= 5.0 && hours <= 6.0 {
            return 40 // Very poor
        } else if hours < 5.0 {
            return 20 // Critical
        } else if hours > 9.5 {
            return 85 // Too much sleep (slight penalty)
        }
        return 50
    }
    
    private func calculateEfficiencyScore(_ efficiency: Double) -> Double {
        // Efficiency as percentage (0-1 scale)
        if efficiency >= 0.90 {
            return 100 // Excellent
        } else if efficiency >= 0.85 {
            return 90 // Very good
        } else if efficiency >= 0.80 {
            return 80 // Good
        } else if efficiency >= 0.75 {
            return 70 // Fair
        } else if efficiency >= 0.70 {
            return 60 // Poor
        } else if efficiency >= 0.65 {
            return 40 // Very poor
        } else {
            return 20 // Critical
        }
    }
    
    private func calculateREMScore(_ remPercentage: Double) -> Double {
        // Optimal REM: 20-25%
        if remPercentage >= 20.0 && remPercentage <= 25.0 {
            return 100 // Perfect
        } else if remPercentage >= 18.0 && remPercentage <= 27.0 {
            return 90 // Excellent
        } else if remPercentage >= 15.0 && remPercentage <= 30.0 {
            return 80 // Good
        } else if remPercentage >= 12.0 && remPercentage <= 33.0 {
            return 70 // Fair
        } else if remPercentage >= 10.0 && remPercentage <= 35.0 {
            return 60 // Poor
        } else {
            return 40 // Very poor
        }
    }
    
    private func calculateDeepScore(_ deepPercentage: Double) -> Double {
        // Optimal Deep: 15-20%
        if deepPercentage >= 15.0 && deepPercentage <= 20.0 {
            return 100 // Perfect
        } else if deepPercentage >= 13.0 && deepPercentage <= 22.0 {
            return 90 // Excellent
        } else if deepPercentage >= 10.0 && deepPercentage <= 25.0 {
            return 80 // Good
        } else if deepPercentage >= 8.0 && deepPercentage <= 28.0 {
            return 70 // Fair
        } else if deepPercentage >= 5.0 && deepPercentage <= 30.0 {
            return 60 // Poor
        } else {
            return 40 // Very poor
        }
    }
    
    private func calculateWASOPenalty(_ wasoMinutes: Double) -> Double {
        // WASO penalty: more wake time = lower score
        if wasoMinutes <= 5.0 {
            return 0 // No penalty
        } else if wasoMinutes <= 10.0 {
            return 2.0 // Small penalty
        } else if wasoMinutes <= 20.0 {
            return 5.0 // Moderate penalty
        } else if wasoMinutes <= 30.0 {
            return 10.0 // Large penalty
        } else {
            return 15.0 // Severe penalty
        }
    }

    private func calculateStrainScore(_ data: HealthData) -> HealthScore.ScoreComponent {
        guard data.hasStrainData else {
            return HealthScore.ScoreComponent(
                value: 0,
                status: .unavailable,
                trend: nil,
                subMetrics: nil
            )
        }

        var score = 50.0 // Base score
        var subMetrics: [String: Double] = [:]

        // Energy burned contribution (50% weight)
        if let energy = data.energyBurned {
            subMetrics["Energy Burned"] = energy

            if let baseline = baselineData.energyBaseline {
                let energyRatio = energy / baseline
                if energyRatio > 1.5 {
                    score += 25 // High strain
                } else if energyRatio > 1.2 {
                    score += 15
                } else if energyRatio < 0.8 {
                    score -= 15 // Low strain
                }
            } else {
                // No baseline, use absolute energy
                if energy > 800 {
                    score += 20
                } else if energy > 500 {
                    score += 10
                } else if energy < 200 {
                    score -= 10
                }
            }
        }

        // Heart rate contribution (30% weight)
        if let hr = data.heartRate {
            subMetrics["Avg Heart Rate"] = hr

            if hr > 120 {
                score += 15 // High intensity
            } else if hr > 100 {
                score += 8
            } else if hr < 70 {
                score -= 10 // Low intensity
            }
        }

        // Workout minutes contribution (20% weight)
        if let workout = data.workoutMinutes {
            subMetrics["Workout Minutes"] = workout

            if workout > 90 {
                score += 10
            } else if workout > 60 {
                score += 5
            } else if workout < 20 {
                score -= 5
            }
        }

        // Clamp score between 0-100
        score = max(0, min(100, score))

        let status: HealthScore.ScoreStatus
        if score >= 70 {
            status = .optimal // High strain (good activity)
        } else if score >= 40 {
            status = .moderate
        } else {
            status = .poor // Low strain (needs more activity)
        }

        return HealthScore.ScoreComponent(
            value: score,
            status: status,
            trend: nil,
            subMetrics: subMetrics
        )
    }

    private func calculateStressScore(_ data: HealthData) -> HealthScore.ScoreComponent {
        // For now, use HRV variability as a proxy for stress
        // In a full implementation, this would include symptom logs and breathing data

        if let hrv = data.hrv {
            // Lower HRV can indicate higher stress
            var stressLevel = 50.0

            if let baseline = baselineData.hrvBaseline {
                let hrvRatio = hrv / baseline
                if hrvRatio < 0.8 {
                    stressLevel += 25 // High stress
                } else if hrvRatio < 0.9 {
                    stressLevel += 15
                } else if hrvRatio > 1.1 {
                    stressLevel -= 20 // Low stress
                }
            }

            stressLevel = max(0, min(100, stressLevel))

            let status: HealthScore.ScoreStatus
            if stressLevel >= 70 {
                status = .poor // High stress (needs attention)
            } else if stressLevel >= 40 {
                status = .moderate
            } else {
                status = .optimal // Low stress (excellent)
            }

            return HealthScore.ScoreComponent(
                value: stressLevel,
                status: status,
                trend: nil,
                subMetrics: ["HRV Variability": hrv]
            )
        } else {
            return HealthScore.ScoreComponent(
                value: 0,
                status: .unavailable,
                trend: nil,
                subMetrics: nil
            )
        }
    }

    // MARK: - Trend Calculations

    func calculateTrend(for scores: [HealthScore], scoreType: String, days: Int = 7) -> [Double] {
        let recentScores = scores.suffix(days)

        switch scoreType {
        case "recovery":
            return recentScores.map { $0.recovery.value }
        case "sleep":
            return recentScores.map { $0.sleep.value }
        case "strain":
            return recentScores.map { $0.strain.value }
        case "stress":
            return recentScores.map { $0.stress.value }
        default:
            return []
        }
    }

    // MARK: - Baseline Management

    func getBaseline() -> HealthBaseline {
        return baselineData
    }

    func updateBaseline(with data: HealthData) {
        baselineData.update(with: data)
    }

    // MARK: - Simplified Score Methods for ScoreManager
    
    /// Simplified recovery score calculation for reactive updates
    func recoveryScore(hrv: Double, rhr: Double, sleepHours: Double?) -> Double {
        let data = HealthData(
            date: Date(),
            hrv: hrv,
            restingHeartRate: rhr,
            heartRate: nil,
            energyBurned: nil,
            sleepSession: nil,
            sleepDuration: sleepHours,
            sleepEfficiency: nil,
            deepSleep: nil,
            remSleep: nil,
            wakeEvents: nil,
            workoutMinutes: nil,
            vo2Max: nil,
            weight: nil,
            leanBodyMass: nil,
            bodyFat: nil
        )
        return calculateRecoveryScore(data).value
    }
    
    /// Simplified sleep score calculation for reactive updates
    func sleepScore(sleepHours: Double, efficiency: Double?) -> Double {
        let data = HealthData(
            date: Date(),
            hrv: nil,
            restingHeartRate: nil,
            heartRate: nil,
            energyBurned: nil,
            sleepSession: nil, // Use basic scoring
            sleepDuration: sleepHours,
            sleepEfficiency: efficiency,
            deepSleep: nil,
            remSleep: nil,
            wakeEvents: nil,
            workoutMinutes: nil,
            vo2Max: nil,
            weight: nil,
            leanBodyMass: nil,
            bodyFat: nil
        )
        return calculateSleepScore(data).value
    }
    
    /// Comprehensive sleep score using sleep session
    func comprehensiveSleepScore(from session: SleepSession) -> Double {
        let data = HealthData(
            date: Date(),
            hrv: nil,
            restingHeartRate: nil,
            heartRate: nil,
            energyBurned: nil,
            sleepSession: session, // Use comprehensive scoring
            sleepDuration: session.durationHours,
            sleepEfficiency: session.efficiency,
            deepSleep: session.stages.deep / 3600.0, // Convert to hours
            remSleep: session.stages.rem / 3600.0,   // Convert to hours
            wakeEvents: session.wakeEvents,
            workoutMinutes: nil,
            vo2Max: nil,
            weight: nil,
            leanBodyMass: nil,
            bodyFat: nil
        )
        return calculateSleepScore(data).value
    }
    
    /// Enhanced sleep score with efficiency and stages
    func enhancedSleepScore(sleepHours: Double, efficiency: Double?, deepSleep: Double?, remSleep: Double?, wakeEvents: Int?) -> Double {
        let data = HealthData(
            date: Date(),
            hrv: nil,
            restingHeartRate: nil,
            heartRate: nil,
            energyBurned: nil,
            sleepSession: nil,
            sleepDuration: sleepHours,
            sleepEfficiency: efficiency,
            deepSleep: deepSleep,
            remSleep: remSleep,
            wakeEvents: wakeEvents,
            workoutMinutes: nil,
            vo2Max: nil,
            weight: nil,
            leanBodyMass: nil,
            bodyFat: nil
        )
        return calculateSleepScore(data).value
    }
    
    /// Simplified strain score calculation for reactive updates
    func strainScore(steps: Double, energy: Double, baseline: HealthBaseline?) -> Double {
        let data = HealthData(
            date: Date(),
            hrv: nil,
            restingHeartRate: nil,
            heartRate: nil,
            energyBurned: energy,
            sleepSession: nil,
            sleepDuration: nil,
            sleepEfficiency: nil,
            deepSleep: nil,
            remSleep: nil,
            wakeEvents: nil,
            workoutMinutes: nil,
            vo2Max: nil,
            weight: nil,
            leanBodyMass: nil,
            bodyFat: nil
        )
        return calculateStrainScore(data).value
    }
    
    /// Personalized strain score using rolling baselines
    func personalizedStrainScore(steps: Double, energy: Double, stepsBaseline: BaselineStats?, energyBaseline: BaselineStats?) -> Double {
        var totalScore = 0.0
        var weightSum = 0.0
        
        // Steps component (40% weight) - use personalized baseline if available
        if let baseline = stepsBaseline, baseline.count >= 7 {
            let personalizedScore = baseline.normalizedScore(value: steps)
            totalScore += personalizedScore * 0.4
            weightSum += 0.4
        } else {
            // Fallback to static thresholds
            let staticScore = staticStepsScore(steps)
            totalScore += staticScore * 0.4
            weightSum += 0.4
        }
        
        // Energy component (60% weight) - use personalized baseline if available
        if let baseline = energyBaseline, baseline.count >= 7 {
            let personalizedScore = baseline.normalizedScore(value: energy)
            totalScore += personalizedScore * 0.6
            weightSum += 0.6
        } else {
            // Fallback to static thresholds
            let staticScore = staticEnergyScore(energy)
            totalScore += staticScore * 0.6
            weightSum += 0.6
        }
        
        return weightSum > 0 ? totalScore / weightSum : 50.0
    }
    
    // MARK: - Static Fallback Methods
    
    private func staticStepsScore(_ steps: Double) -> Double {
        if steps >= 12000 { return 90 + min(10, (steps - 12000) / 3000 * 10) }
        else if steps >= 8000 { return 70 + ((steps - 8000) / 4000) * 20 }
        else if steps >= 5000 { return 40 + ((steps - 5000) / 3000) * 30 }
        else if steps >= 2000 { return 20 + ((steps - 2000) / 3000) * 20 }
        else { return max(5, steps / 2000 * 20) }
    }
    
    private func staticEnergyScore(_ energy: Double) -> Double {
        if energy >= 600 { return 85 + min(15, (energy - 600) / 200 * 15) }
        else if energy >= 400 { return 65 + ((energy - 400) / 200) * 20 }
        else if energy >= 200 { return 35 + ((energy - 200) / 200) * 30 }
        else if energy >= 100 { return 15 + ((energy - 100) / 100) * 20 }
        else { return max(5, energy / 100 * 15) }
    }
}
