import SwiftUI

struct JournalView: View {
    @StateObject private var viewModel = JournalViewModel()
    @State private var showingCustomizeJournal = false
    @State private var showingDatePicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        headerSection
                        
                        // Daily Questions
                        dailyQuestionsSection
                        
                        // Bottom padding
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCustomizeJournal) {
                // Simple settings view instead of complex customization
                NavigationView {
                    Text("Journal Settings")
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingCustomizeJournal = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationView {
                    DatePicker("Select Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .navigationTitle("Select Date")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    showingDatePicker = false
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingDatePicker = false
                                    viewModel.changeDate(to: viewModel.selectedDate)
                                }
                            }
                        }
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Top navigation
            HStack {
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(Constants.Strings.journalTitle)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                    .tracking(1)
                
                Spacer()
                
                Button(action: { showingCustomizeJournal = true }) {
                    Image(systemName: "gear")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            
            // Date question
            VStack(spacing: 8) {
                Button(action: {
                    showingDatePicker = true
                }) {
                    Text(viewModel.dateQuestion)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(Constants.Strings.circadianHealth)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .tracking(1)
            }
        }
    }
    
    // MARK: - Daily Questions Section
    private var dailyQuestionsSection: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.journalQuestions.filter(viewModel.isQuestionVisible), id: \.id) { question in
                journalQuestionCard(for: question)
            }
        }
    }
    
    // MARK: - Journal Question Card
    private func journalQuestionCard(for question: JournalQuestion) -> some View {
        let currentAnswer = viewModel.getAnswer(for: question.id)
        
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(question.question)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let answer = currentAnswer {
                    Text(answer.displayText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                } else {
                    Text(placeholderText(for: question.type))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Answer buttons based on question type
            questionInputView(for: question, currentAnswer: currentAnswer)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Helper Functions
    private func placeholderText(for type: JournalQuestionType) -> String {
        switch type {
        case .yesNo:
            return Constants.Strings.tapToAnswer
        case .numeric(let unit):
            return "-- \(unit ?? "")"
        case .time:
            return "-- : --"
        case .counter:
            return "0"
        case .text:
            return Constants.Strings.addNote
        case .scale(let range):
            return "\(range.lowerBound) - \(range.upperBound)"
        case .multipleChoice:
            return Constants.Strings.tapToAnswer
        case .boolean:
            return Constants.Strings.tapToAnswer
        }
    }
    
    @ViewBuilder
    private func questionInputView(for question: JournalQuestion, currentAnswer: JournalResponseValue?) -> some View {
        switch question.type {
        case .yesNo:
            HStack(spacing: 12) {
                answerButton(
                    type: .no,
                    isSelected: {
                        if case .boolean(let value) = currentAnswer {
                            return !value
                        }
                        return false
                    }(),
                    action: {
                        viewModel.updateAnswer(for: question.id, answer: .boolean(false))
                    }
                )
                answerButton(
                    type: .yes,
                    isSelected: {
                        if case .boolean(let value) = currentAnswer {
                            return value
                        }
                        return false
                    }(),
                    action: {
                        viewModel.updateAnswer(for: question.id, answer: .boolean(true))
                    }
                )
            }
        case .numeric, .counter:
            Button(action: {
                // In a real app, this would show a number picker
                viewModel.updateAnswer(for: question.id, answer: .number(15))
            }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
        case .time:
            Button(action: {
                // In a real app, this would show a time picker
                viewModel.updateAnswer(for: question.id, answer: .time(Date()))
            }) {
                Image(systemName: "clock")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
        case .text:
            Button(action: {
                // In a real app, this would show a text input
                viewModel.updateAnswer(for: question.id, answer: .text("Sample text"))
            }) {
                Image(systemName: "pencil")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
        case .scale:
            Button(action: {
                // In a real app, this would show a scale picker
                viewModel.updateAnswer(for: question.id, answer: .scale(5))
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
        case .multipleChoice:
            Button(action: {
                // In a real app, this would show options picker
                if let firstOption = question.options?.first {
                    viewModel.updateAnswer(for: question.id, answer: .multipleChoice(firstOption))
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
        case .boolean:
            HStack(spacing: 12) {
                answerButton(
                    type: .no,
                    isSelected: {
                        if case .boolean(let value) = currentAnswer {
                            return !value
                        }
                        return false
                    }(),
                    action: {
                        viewModel.updateAnswer(for: question.id, answer: .boolean(false))
                    }
                )
                answerButton(
                    type: .yes,
                    isSelected: {
                        if case .boolean(let value) = currentAnswer {
                            return value
                        }
                        return false
                    }(),
                    action: {
                        viewModel.updateAnswer(for: question.id, answer: .boolean(true))
                    }
                )
            }
        }
    }
    
    // MARK: - Answer Button
    private func answerButton(type: JournalAnswer, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: type == .yes ? "checkmark" : "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? (type == .yes ? .green : .red) : Color(.systemGray5))
                )
        }
    }
} 