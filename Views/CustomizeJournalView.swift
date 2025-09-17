import SwiftUI

struct CustomizeJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory = Constants.Strings.all
    @StateObject private var viewModel = JournalViewModel()
    
    private let categories = [
        Constants.Strings.all,
        Constants.Strings.circadianHealth,
        Constants.Strings.lifestyle,
        Constants.Strings.medication,
        Constants.Strings.nutrition,
        Constants.Strings.sleep_category
    ]
    
    private let journalItems = [
        JournalItem(name: Constants.Strings.acupuncture, category: Constants.Strings.lifestyle),
        JournalItem(name: Constants.Strings.addedSugar, category: Constants.Strings.nutrition),
        JournalItem(name: Constants.Strings.adhdMedication, category: Constants.Strings.medication),
        JournalItem(name: Constants.Strings.airTravel, category: Constants.Strings.lifestyle),
        JournalItem(name: Constants.Strings.alcohol, category: Constants.Strings.lifestyle),
        JournalItem(name: Constants.Strings.antiAnxietyMedication, category: Constants.Strings.medication),
        JournalItem(name: Constants.Strings.antiInflammatory, category: Constants.Strings.medication),
        JournalItem(name: Constants.Strings.anxiety, category: Constants.Strings.lifestyle),
        JournalItem(name: Constants.Strings.artificialLight, category: Constants.Strings.circadianHealth),
        JournalItem(name: Constants.Strings.blueLightExposure, category: Constants.Strings.circadianHealth),
        JournalItem(name: Constants.Strings.caffeine, category: Constants.Strings.nutrition),
        JournalItem(name: Constants.Strings.coldExposure, category: Constants.Strings.lifestyle),
        JournalItem(name: Constants.Strings.exercise, category: Constants.Strings.lifestyle),
        JournalItem(name: Constants.Strings.lateMeals, category: Constants.Strings.nutrition),
        JournalItem(name: Constants.Strings.meditation, category: Constants.Strings.lifestyle),
        JournalItem(name: Constants.Strings.sleepQuality, category: Constants.Strings.sleep_category),
        JournalItem(name: Constants.Strings.stress_category, category: Constants.Strings.lifestyle),
        JournalItem(name: Constants.Strings.supplements, category: Constants.Strings.nutrition),
        JournalItem(name: Constants.Strings.waterIntake, category: Constants.Strings.nutrition)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text(Constants.Strings.customizeJournalTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(1)
                        
                        Spacer()
                        
                        Button(Constants.Strings.done) {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    
                    // Category Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.self) { category in
                                categoryPill(category)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    
                    // Journal Items List
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredItems, id: \.name) { item in
                                journalItemRow(item)
                            }
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var filteredItems: [JournalItem] {
        if selectedCategory == Constants.Strings.all {
            return journalItems
        }
        return journalItems.filter { $0.category == selectedCategory }
    }
    
    private func categoryPill(_ category: String) -> some View {
        Button(action: { selectedCategory = category }) {
            Text(category)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selectedCategory == category ? Color.accentColor : Color(.systemGray5))
                )
                .foregroundColor(selectedCategory == category ? .white : .secondary)
        }
    }
    
    private func journalItemRow(_ item: JournalItem) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleJournalItem(item.name)
                }
            }) {
                Image(systemName: viewModel.isItemEnabled(item.name) ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.isItemEnabled(item.name) ? .red : .green)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

struct JournalItem {
    let name: String
    let category: String
    
    var subtitle: String {
        switch category {
        case Constants.Strings.circadianHealth:
            return Constants.Strings.optimizeNaturalRhythm
        case Constants.Strings.lifestyle:
            return Constants.Strings.trackDailyHabits
        case Constants.Strings.medication:
            return Constants.Strings.monitorMedicationEffects
        case Constants.Strings.nutrition:
            return Constants.Strings.trackNutritionFactors
        case Constants.Strings.sleep_category:
            return Constants.Strings.trackSleepQuality
        default:
            return Constants.Strings.dailyTracking
        }
    }
} 