import SwiftUI
import Charts
import HealthKit

struct FitnessView: View {
    @StateObject private var dataManager = DataManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Text("Fitness")
                        .font(.system(size: 32, weight: .semibold))
                    Text("Last 30 days")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 14)

                // Steps card
                StepsCard(steps: dataManager.stepsSeries)
                    .padding(.horizontal, 20)

                // Active energy card
                ActiveEnergyCard(energy: dataManager.activeEnergySeries)
                    .padding(.horizontal, 20)

                // Recent workouts list
                WorkoutsList(workouts: dataManager.recentWorkouts)
                    .padding(.horizontal, 20)

                // Workouts by type (minutes) chart
                WorkoutsByTypeChart(workouts: dataManager.recentWorkouts)
                    .padding(.horizontal, 20)

                Spacer(minLength: 80)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await HealthKitManager.shared.loadActivity30Days()
                await HealthKitManager.shared.loadWorkouts30Days()
            }
        }
    }
}

private struct StepsCard: View {
    let steps: [HealthMetricPoint]
    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("d") // day of month
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundColor(.secondary)
                Text("Steps")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }

            if steps.isEmpty {
                Text("No steps data. Connect HealthKit and keep moving.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                let today = calendar.startOfDay(for: Date())
                Chart(steps) { point in
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("Steps", point.value)
                    )
                    .foregroundStyle(point.isActualData ? .blue.opacity(0.8) : .blue.opacity(0.3))

                    // Optional highlight for today
                    if calendar.isDate(point.date, inSameDayAs: today) {
                        RuleMark(x: .value("Today", point.date))
                            .foregroundStyle(.red.opacity(0.5))
                    }
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) { value in
                        if let date = value.as(Date.self) {
                            AxisGridLine()
                            AxisValueLabel(dayFormatter.string(from: date))
                        }
                    }
                }

                if let last = steps.last {
                    HStack {
                        Text("Latest: \(Int(last.value)) steps")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 8, x: 0, y: 2)
        )
    }
}

private struct WorkoutsList: View {
    let workouts: [WorkoutSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text("Recent Workouts")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }

            if workouts.isEmpty {
                Text("No workouts in the last 30 days.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                ForEach(workouts.prefix(8)) { w in
                    HStack {
                        Text(workoutName(w.type))
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        Text(String(format: "%.0f min", w.durationMinutes))
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f kcal", w.energyKilocalories))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 8, x: 0, y: 2)
        )
    }
}

private struct WorkoutsByTypeChart: View {
    let workouts: [WorkoutSummary]

    struct TypeBucket: Identifiable { let id = UUID(); let type: HKWorkoutActivityType; let minutes: Double }

    var buckets: [TypeBucket] {
        let grouped = Dictionary(grouping: workouts) { $0.type }
        return grouped.map { (type, items) in
            TypeBucket(type: type, minutes: items.reduce(0) { $0 + $1.durationMinutes })
        }.sorted { $0.minutes > $1.minutes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.secondary)
                Text("Minutes by Type (30d)")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }

            if buckets.isEmpty {
                Text("No workout data available.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                Chart(buckets) { b in
                    BarMark(
                        x: .value("Minutes", b.minutes),
                        y: .value("Type", workoutName(b.type))
                    )
                    .foregroundStyle(.green)
                }
                .frame(height: min(240, CGFloat(buckets.count) * 28))
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 8, x: 0, y: 2)
        )
    }
}

private func workoutName(_ type: HKWorkoutActivityType) -> String {
    switch type {
    case .running: return "Running"
    case .walking: return "Walking"
    case .cycling: return "Cycling"
    case .swimming: return "Swimming"
    case .yoga: return "Yoga"
    case .traditionalStrengthTraining: return "Strength"
    case .highIntensityIntervalTraining: return "HIIT"
    default: return String(describing: type)
    }
}

private struct ActiveEnergyCard: View {
    let energy: [HealthMetricPoint]
    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("d")
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.secondary)
                Text("Active Energy")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }

            if energy.isEmpty {
                Text("No active energy data.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                let today = calendar.startOfDay(for: Date())
                Chart(energy) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("kcal", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(.orange)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("kcal", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.orange.opacity(0.1))

                    if calendar.isDate(point.date, inSameDayAs: today) {
                        RuleMark(x: .value("Today", point.date))
                            .foregroundStyle(.red.opacity(0.5))
                    }
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) { value in
                        if let date = value.as(Date.self) {
                            AxisGridLine()
                            AxisValueLabel(dayFormatter.string(from: date))
                        }
                    }
                }

                if let last = energy.last {
                    HStack {
                        Text("Latest: \(Int(last.value)) kcal")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 8, x: 0, y: 2)
        )
    }
}

struct FitnessView_Previews: PreviewProvider {
    static var previews: some View {
        FitnessView()
    }
}
