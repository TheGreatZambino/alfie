import SwiftUI
import SwiftData

/// Retirement setup: household, each person's details, and the income target. This is the only
/// place the app asks for gross income, and it only runs once the user opts into the Retirement
/// tab. Also used to edit an existing plan.
struct RetirementSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var plans: [RetirementPlan]
    @Query(sort: \PlanPerson.order) private var existingPeople: [PlanPerson]
    @Query(sort: \RetirementAccount.name) private var accounts: [RetirementAccount]
    @Query private var incomes: [Income]

    private struct PersonDraft {
        var name = ""
        var birthDate = Calendar.current.date(byAdding: .year, value: -35, to: Date()) ?? Date()
        var grossText = ""
        var retirementAge = 67
    }

    private enum Step: Int, CaseIterable {
        case household, people, target
    }

    @State private var step: Step = .household
    @State private var isCouple = false
    @State private var drafts = [PersonDraft(), PersonDraft()]
    @State private var targetMode: RetirementTargetMode = .percentOfGross
    @State private var targetPercent: Double = RetirementPlan.defaultTargetPercent
    @State private var targetDollarsText = ""
    @State private var didLoad = false

    private var activeCount: Int { isCouple ? 2 : 1 }

    private var combinedGross: Double {
        drafts.prefix(activeCount).reduce(0) { $0 + (Double($1.grossText) ?? 0) }
    }

    private var targetDollars: Double { Double(targetDollarsText) ?? 0 }

    private var canContinue: Bool {
        switch step {
        case .household: return true
        case .people: return drafts.prefix(activeCount).allSatisfy { (Double($0.grossText) ?? 0) > 0 }
        case .target:
            return targetMode == .percentOfGross ? targetPercent > 0 : targetDollars > 0
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .household: householdStep
                case .people: peopleStep
                case .target: targetStep
                }
            }
            .alfieListStyle()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { navigationBar }
            .onAppear(perform: loadExisting)
        }
    }

    private var title: String {
        switch step {
        case .household: return "Who is this for?"
        case .people: return "About you"
        case .target: return "Retirement income goal"
        }
    }

    // MARK: - Steps

    private var householdStep: some View {
        Form {
            Section {
                householdOption(title: "Just me", subtitle: "Single filer", icon: "person.fill", selected: !isCouple) { isCouple = false }
                householdOption(title: "Me and my partner", subtitle: "Married filing jointly", icon: "person.2.fill", selected: isCouple) { isCouple = true }
            } footer: {
                Text("This sets whether the plan covers one person or two, and which tax filing status is used for estimates.")
            }
        }
    }

    private func householdOption(title: String, subtitle: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconBadge(systemName: icon, color: .retirement, size: 36, shape: .roundedSquare(radius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.rowTitle).foregroundStyle(Color.ink)
                    Text(subtitle).font(.rowDetail).foregroundStyle(Color.inkTertiary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.retirement : Color.inkQuaternary)
                    .font(.system(size: 20))
            }
        }
        .buttonStyle(.plain)
    }

    private var peopleStep: some View {
        Form {
            ForEach(0..<activeCount, id: \.self) { index in
                Section {
                    TextField(index == 0 ? "Your name (optional)" : "Partner's name (optional)", text: $drafts[index].name)
                    DatePicker("Date of birth", selection: $drafts[index].birthDate, in: ...Date(), displayedComponents: .date)
                    HStack {
                        Text("Gross income / year")
                        Spacer()
                        CurrencyTextField(placeholder: "0", text: $drafts[index].grossText)
                            .frame(maxWidth: 140)
                    }
                    Stepper(value: $drafts[index].retirementAge, in: 50...75) {
                        HStack {
                            Text("Retire at")
                            Spacer()
                            Text("\(drafts[index].retirementAge)")
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                } header: {
                    if isCouple { Text(index == 0 ? "You" : "Your partner") }
                } footer: {
                    if index == activeCount - 1 { grossIncomeFooter }
                }
            }
        }
    }

    @ViewBuilder
    private var grossIncomeFooter: some View {
        if let income = incomes.first, income.amount > 0 {
            let takeHomeYearly = income.amount * income.cadence.periodsPerMonth * 12
            Text("Enter pay before taxes and deductions, not take-home. For reference, your take-home pay in Finances works out to about \(takeHomeYearly.formatted(.currency(code: "USD").precision(.fractionLength(0)))) a year, so gross pay will be higher.")
        } else {
            Text("Enter pay before taxes and deductions, not take-home. Retirement planning uses gross income because taxes and Social Security are based on it.")
        }
    }

    private var targetStep: some View {
        Form {
            Section {
                Picker("Express my goal as", selection: $targetMode) {
                    Text("% of income").tag(RetirementTargetMode.percentOfGross)
                    Text("$ per year").tag(RetirementTargetMode.fixedDollars)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("You can set your goal either way. We start with 80% of your gross income, a common rule of thumb. Switch to a dollar amount if you have a specific number in mind.")
            }

            Section {
                if targetMode == .percentOfGross {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(targetPercent))%")
                                .font(.cardNumeral)
                                .foregroundStyle(Color.ink)
                            Text("of gross income")
                                .font(.rowDetail)
                                .foregroundStyle(Color.inkTertiary)
                            Spacer()
                            if targetPercent != RetirementPlan.defaultTargetPercent {
                                Button("Reset to 80%") { targetPercent = RetirementPlan.defaultTargetPercent }
                                    .font(.system(size: 13, weight: .semibold))
                                    .tint(.retirement)
                            }
                        }
                        Slider(value: $targetPercent, in: 30...120, step: 1)
                            .tint(.retirement)
                    }
                    .padding(.vertical, 4)

                    resultRow(label: "That's about", value: currency(combinedGross * targetPercent / 100) + " / year")
                } else {
                    HStack {
                        Text("Per year")
                        Spacer()
                        CurrencyTextField(placeholder: "0", text: $targetDollarsText, fontSize: 20)
                            .frame(maxWidth: 160)
                    }
                    if combinedGross > 0, targetDollars > 0 {
                        resultRow(label: "That's about", value: String(format: "%.0f%% of your gross income", targetDollars / combinedGross * 100))
                    }
                }
            } footer: {
                HStack(spacing: 4) {
                    Text("Amounts are in today's dollars.")
                    NavigationLink {
                        RetirementSourcesView()
                    } label: {
                        Text("Why 80%?")
                    }
                    .tint(.retirement)
                }
            }
        }
    }

    private func resultRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.inkSecondary)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(Color.ink)
        }
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack(spacing: 12) {
            if step != .household {
                Button("Back") {
                    if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
                }
                .buttonStyle(.bordered)
                .tint(.retirement)
            }
            Button(step == .target ? "Save plan" : "Continue") {
                if let next = Step(rawValue: step.rawValue + 1) {
                    step = next
                } else {
                    save()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.retirementFill)
            .frame(maxWidth: .infinity)
            .disabled(!canContinue)
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.paper)
    }

    // MARK: - Load / save

    private func loadExisting() {
        guard !didLoad else { return }
        didLoad = true
        guard let plan = plans.first else { return }
        isCouple = plan.isCouple
        targetMode = plan.targetMode
        targetPercent = plan.targetPercent
        if plan.targetDollars > 0 { targetDollarsText = String(format: "%.2f", plan.targetDollars) }
        for person in existingPeople.prefix(2) where person.order < drafts.count {
            drafts[person.order] = PersonDraft(
                name: person.name,
                birthDate: person.birthDate,
                grossText: person.grossAnnualIncome > 0 ? String(format: "%.2f", person.grossAnnualIncome) : "",
                retirementAge: person.retirementAge
            )
        }
    }

    private func save() {
        let plan = plans.first ?? {
            let new = RetirementPlan()
            modelContext.insert(new)
            return new
        }()
        plan.isCouple = isCouple
        plan.targetMode = targetMode
        plan.targetPercent = targetPercent
        plan.targetDollars = targetDollars
        plan.isSetupComplete = true

        for index in 0..<activeCount {
            let draft = drafts[index]
            let person = existingPeople.first(where: { $0.order == index }) ?? {
                let new = PlanPerson(order: index)
                modelContext.insert(new)
                return new
            }()
            person.name = draft.name.trimmingCharacters(in: .whitespaces)
            person.birthDate = draft.birthDate
            person.grossAnnualIncome = Double(draft.grossText) ?? 0
            person.retirementAge = draft.retirementAge
        }

        // Switching back to a single filer: drop the partner and hand their accounts to the user.
        if !isCouple {
            for person in existingPeople where person.order >= 1 { modelContext.delete(person) }
            for account in accounts where account.ownerOrder >= 1 { account.ownerOrder = 0 }
        }

        try? modelContext.save()
        dismiss()
    }
}
