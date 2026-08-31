import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var incomes: [Income]
    @Query private var categories: [Category]

    @AppStorage(TrackedModule.storageKey) private var trackedModulesRaw = TrackedModule.defaultRawValue

    private enum SetupStep: Hashable {
        case modules
        case incomeAmount
        case cadence
        case payday
    }

    private enum Phase: Hashable {
        case setup(SetupStep)
        case tour(TourPage)
    }

    @State private var stepIndex: Int = 0
    @State private var selectedModules: Set<TrackedModule> = Set(TrackedModule.allCases)
    @State private var amountText: String = ""
    @State private var cadence: PayCadence = .biweekly
    @State private var nextPayDate: Date = Date()
    @State private var didSaveSetup = false

    private var setupSteps: [SetupStep] {
        var steps: [SetupStep] = [.modules]
        if selectedModules.contains(.finance) {
            steps += [.incomeAmount, .cadence, .payday]
        }
        return steps
    }

    private var steps: [Phase] {
        setupSteps.map(Phase.setup) + TourPage.pages(for: selectedModules).map(Phase.tour)
    }

    private var currentPhase: Phase { steps[stepIndex] }
    private var isLastStep: Bool { stepIndex == steps.count - 1 }
    private var isTourPhase: Bool {
        if case .tour = currentPhase { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar

                VStack(alignment: .leading, spacing: 24) {
                    switch currentPhase {
                    case .setup(.modules):
                        stepView(
                            eyebrow: stepEyebrow,
                            headline: "What do you want to track?",
                            body: "Pick as many as you like — you can always change this later in Settings."
                        ) {
                            moduleChips
                        }
                    case .setup(.incomeAmount):
                        stepView(
                            eyebrow: stepEyebrow,
                            headline: "What do you take home each pay period?",
                            body: "Everything else — bills, savings, what's left to spend — is worked out from this."
                        ) {
                            amountInputCard
                        }
                    case .setup(.cadence):
                        stepView(
                            eyebrow: stepEyebrow,
                            headline: "How often are you paid?",
                            body: "This sets the rhythm for your budget periods and bill allocations."
                        ) {
                            cadenceChips
                        }
                    case .setup(.payday):
                        stepView(
                            eyebrow: stepEyebrow,
                            headline: "When's your next payday?",
                            body: "We'll count down to it and reset your period balance when it arrives."
                        ) {
                            VStack {
                                DatePicker("Next pay date", selection: $nextPayDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .tint(.money)
                            }
                            .cardStyle()
                        }
                    case .tour(let page):
                        TourPageView(page: page)
                        if isLastStep {
                            SupportAlfieSection()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 36)

                Spacer()

                footer
            }
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var stepEyebrow: String {
        "STEP \(stepIndex + 1) OF \(steps.count)"
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index <= stepIndex ? Color.money : Color.ink.opacity(0.10))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private func stepView<Content: View>(eyebrow: String, headline: String, body: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(eyebrow)
                .eyebrowStyle(color: .money)

            Text(headline)
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.4)
                .lineSpacing(2)
                .foregroundStyle(Color.ink)

            Text(body)
                .font(.system(size: 16))
                .lineSpacing(4)
                .foregroundStyle(Color.inkSecondary)

            content()
                .padding(.top, 8)
        }
    }

    private var moduleChips: some View {
        VStack(spacing: 10) {
            ForEach(TrackedModule.allCases) { module in
                let isSelected = selectedModules.contains(module)
                Button {
                    if isSelected {
                        selectedModules.remove(module)
                    } else {
                        selectedModules.insert(module)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: module.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : Color.inkSecondary)
                            .frame(width: 28)

                        Text(module.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : Color.ink)

                        Spacer()

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(isSelected ? .white : Color.inkQuaternary)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(isSelected ? Color.money : Color.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? .clear : Color.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var amountInputCard: some View {
        CurrencyTextField(placeholder: "0", text: $amountText)
            .font(.system(size: 44, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity)
            .padding(24)
            .cardStyle()
    }

    private var cadenceChips: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(PayCadence.allCases, id: \.self) { option in
                Button {
                    cadence = option
                } label: {
                    Text(option.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(cadence == option ? .white : Color.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Capsule().fill(cadence == option ? Color.money : Color.card))
                        .overlay(Capsule().strokeBorder(cadence == option ? .clear : Color.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var isContinueDisabled: Bool {
        switch currentPhase {
        case .setup(.modules): return selectedModules.isEmpty
        case .setup(.incomeAmount): return Double(amountText) == nil
        case .setup(.cadence), .setup(.payday), .tour: return false
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Button {
                advance()
            } label: {
                Text(isLastStep ? "Get Started" : "Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.moneyFill)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.moneyFill.opacity(0.28), radius: 10, y: 8)
            }
            .disabled(isContinueDisabled)
            .opacity(isContinueDisabled ? 0.4 : 1)

            Button(isTourPhase ? "Skip tour" : "Set this up later") {
                saveSetupData()
                dismiss()
            }
            .font(.system(size: 14))
            .foregroundStyle(Color.inkTertiary)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
    }

    private func advance() {
        if !isLastStep {
            stepIndex += 1
            // Commit setup data the moment we cross into the tour, so nothing is lost
            // if the user backs out partway through it.
            if isTourPhase { saveSetupData() }
        } else {
            saveSetupData()
            dismiss()
        }
    }

    private func saveSetupData() {
        guard !didSaveSetup else { return }
        didSaveSetup = true

        trackedModulesRaw = TrackedModule.rawValue(from: selectedModules)

        if selectedModules.contains(.finance), let amount = Double(amountText) {
            if let income = incomes.first {
                income.amount = amount
                income.cadence = cadence
                income.nextPayDate = nextPayDate
            } else {
                let income = Income(amount: amount, payCadence: cadence, nextPayDate: nextPayDate)
                modelContext.insert(income)
            }
        }

        if categories.isEmpty {
            var sortOrder = 0
            for seed in Category.defaultSpendingCategories {
                let category = Category(name: seed.name, icon: seed.icon, colorHex: seed.colorHex, type: .spending, sortOrder: sortOrder)
                modelContext.insert(category)
                sortOrder += 1
            }
            for seed in Category.defaultBillCategories {
                let category = Category(name: seed.name, icon: seed.icon, colorHex: seed.colorHex, type: .bill, sortOrder: sortOrder)
                modelContext.insert(category)
                sortOrder += 1
            }
        }

        try? modelContext.save()
    }
}
