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

        var score = 50.0 // Base score
        var subMetrics: [String: Double] = [:]

        // Sleep duration contribution (40% weight)
        if let duration = data.sleepDuration {
            subMetrics["Duration"] = duration

            if duration >= 8 {
                score += 20 // Excellent sleep
            } else if duration >= 7 {
                score += 12
            } else if duration >= 6 {
                score += 5
            } else if duration < 5 {
                score -= 20 // Poor sleep
            } else {
                score -= 10
            }
        }

        // Sleep efficiency contribution (40% weight)
        if let efficiency = data.sleepEfficiency {
            subMetrics["Efficiency"] = efficiency * 100

            if efficiency >= 0.9 {
                score += 20
            } else if efficiency >= 0.85 {
                score += 12
            } else if efficiency >= 0.8 {
                score += 5
            } else if efficiency < 0.75 {
                score -= 20
            } else {
                score -= 10
            }
        }

        // Wake events contribution (20% weight)
        if let wakeEvents = data.wakeEvents {
            subMetrics["Wake Events"] = Double(wakeEvents)

            if wakeEvents == 0 {
                score += 10
            } else if wakeEvents <= 2 {
                score += 5
            } else if wakeEvents > 5 {
                score -= 10
            }
        }

        // Clamp score between 0-100
        score = max(0, min(100, score))

        let status: HealthScore.ScoreStatus
        if score >= 80 {
            status = .optimal
        } else if score >= 60 {
            status = .moderate
        } else {
            status = .poor // Poor means needs attention
        }

        return HealthScore.ScoreComponent(
            value: score,
            status: status,
            trend: nil,
            subMetrics: subMetrics
        )
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

    func resetBaseline() {
        baselineData = HealthBaseline()
    }
}
