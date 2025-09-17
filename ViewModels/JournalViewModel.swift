import Foundation
import SwiftUI

// MARK: - Simple Journal ViewModel

@MainActor
class JournalViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var journalEntries: [JournalEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Journal question data
    @Published var journalQuestions: [JournalQuestion] = []
    @Published var answers: [String: JournalResponseValue] = [:]

    var dateQuestion: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return "How was your day on \(formatter.string(from: selectedDate))?"
    }

    init() {
        setupSampleQuestions()
    }

    private func setupSampleQuestions() {
        journalQuestions = [
            JournalQuestion(
                id: "mood",
                type: .scale(1...10),
                title: "How was your mood today?",
                options: ["Terrible", "Poor", "Okay", "Good", "Excellent"]
            ),
            JournalQuestion(
                id: "energy",
                type: .scale(1...10),
                title: "How was your energy level?",
                options: ["Exhausted", "Tired", "Okay", "Energetic", "Very Energetic"]
            ),
            JournalQuestion(
                id: "sleep",
                type: .scale(1...10),
                title: "How was your sleep quality?",
                options: ["Terrible", "Poor", "Okay", "Good", "Excellent"]
            ),
            JournalQuestion(
                id: "stress",
                type: .scale(1...10),
                title: "How stressed were you today?",
                options: ["Not at all", "A little", "Moderate", "Quite a bit", "Extremely"]
            )
        ]
    }

    // MARK: - Data Loading

    func loadJournalEntries(for date: Date) async {
        selectedDate = date
        isLoading = true

        // Simple implementation - in a real app, this would load from CoreData
        journalEntries = JournalEntry.sampleEntries().filter { entry in
            Calendar.current.isDate(entry.date, inSameDayAs: date)
        }

        isLoading = false
    }

    func saveJournalEntry(_ entry: JournalEntry) {
        journalEntries.append(entry)
        // In a real app, this would save to CoreData
        print("✅ Journal entry saved: \(entry.title)")
    }

    func changeDate(to date: Date) {
        Task {
            await loadJournalEntries(for: date)
        }
    }

    // MARK: - Question Management

    func isQuestionVisible(_ question: JournalQuestion) -> Bool {
        return true // For now, all questions are visible
    }

    func getAnswer(for questionId: String) -> JournalResponseValue? {
        return answers[questionId]
    }

    func updateAnswer(for questionId: String, answer: JournalResponseValue) {
        answers[questionId] = answer
    }

    func deleteJournalEntry(_ entry: JournalEntry) {
        journalEntries.removeAll { $0.id == entry.id }
        // In a real app, this would delete from CoreData
        print("✅ Journal entry deleted")
    }

    // MARK: - Sample Data

    func getSampleQuestions() -> [JournalQuestion] {
        return [
            JournalQuestion(
                id: "mood",
                type: .scale(1...10),
                title: "How are you feeling today?",
                options: ["Poor", "Fair", "Good", "Excellent"]
            ),
            JournalQuestion(
                id: "sleep",
                type: .scale(1...10),
                title: "How was your sleep last night?",
                options: ["Poor", "Fair", "Good", "Excellent"]
            ),
            JournalQuestion(
                id: "energy",
                type: .scale(1...10),
                title: "What's your energy level?",
                options: ["Low", "Moderate", "High", "Very High"]
            )
        ]
    }

    // MARK: - Journal Categories (for compatibility)

    var journalCategories: [String] {
        return [
            "All",
            "Circadian Health",
            "Nutrition",
            "Exercise",
            "Mental Health",
            "Environment"
        ]
    }

    // MARK: - Journal Item Management (for compatibility)

    private var enabledItems: Set<String> = ["Mood", "Sleep", "Energy", "Exercise"]

    func toggleJournalItem(_ itemName: String) {
        if enabledItems.contains(itemName) {
            enabledItems.remove(itemName)
        } else {
            enabledItems.insert(itemName)
        }
    }

    func isItemEnabled(_ itemName: String) -> Bool {
        return enabledItems.contains(itemName)
    }

    func getJournalItems() -> [String] {
        return ["Mood", "Sleep", "Energy", "Exercise", "Nutrition", "Stress"]
    }
}
