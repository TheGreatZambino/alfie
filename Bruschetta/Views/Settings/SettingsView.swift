import SwiftUI
import SwiftData
import StoreKit
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var health = HealthKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage(TrackedModule.storageKey) private var trackedModulesRaw = TrackedModule.defaultRawValue
    @ObservedObject private var subscriptions = SubscriptionManager.shared
    @State private var showTour = false
    @State private var showPaywall = false
    @State private var showManageSubscriptions = false

    @Query private var incomes: [Income]
    @Query private var bills: [Bill]
    @Query private var savingsAccounts: [SavingsAccount]
    @Query private var workoutGoals: [WorkoutGoals]
    @Query private var nutritionGoals: [NutritionGoals]
    @Query private var categories: [Category]

    private var income: Income? { incomes.first }
    private var activeBills: [Bill] { bills.filter(\.isActive) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    settingsGroup(label: "MONEY") {
                        NavigationLink { IncomeSettingsView() } label: {
                            settingsRow(icon: "arrow.down.circle.fill", tint: .money, title: "Income", subtitle: incomeSubtitle)
                        }
                        Divider().overlay(Color.hairline).padding(.leading, 60)
                        NavigationLink { BillsSettingsView() } label: {
                            settingsRow(icon: "doc.text.fill", tint: .money, title: "Bills", subtitle: billsSubtitle)
                        }
                        Divider().overlay(Color.hairline).padding(.leading, 60)
                        NavigationLink { SavingsAccountsSettingsView() } label: {
                            settingsRow(icon: "banknote.fill", tint: .money, title: "Savings & investments", subtitle: "\(savingsAccounts.count) account\(savingsAccounts.count == 1 ? "" : "s")")
                        }
                        Divider().overlay(Color.hairline).padding(.leading, 60)
                        NavigationLink { CategoriesSettingsView() } label: {
                            settingsRow(icon: "square.grid.2x2.fill", tint: .money, title: "Categories", subtitle: categoriesSubtitle)
                        }
                    }

                    settingsGroup(label: "GOALS") {
                        NavigationLink { WorkoutGoalsSettingsView() } label: {
                            settingsRow(icon: "figure.strengthtraining.traditional", tint: .training, title: "Workout goals", subtitle: workoutGoalsSubtitle)
                        }
                        Divider().overlay(Color.hairline).padding(.leading, 60)
                        NavigationLink { NutritionGoalsSettingsView() } label: {
                            settingsRow(icon: "fork.knife", tint: .food, title: "Nutrition goals", subtitle: nutritionGoalsSubtitle)
                        }
                        Divider().overlay(Color.hairline).padding(.leading, 60)
                        Button { openHealthSettings() } label: { healthStatusRow }
                    }

                    settingsGroup(label: "TRACK") {
                        ForEach(Array(TrackedModule.allCases.enumerated()), id: \.element) { index, module in
                            if index > 0 {
                                Divider().overlay(Color.hairline).padding(.leading, 60)
                            }
                            HStack {
                                settingsRow(icon: module.icon, tint: .ink, title: module.displayName, subtitle: nil, showChevron: false)
                                Spacer()
                                Toggle("", isOn: moduleBinding(for: module))
                                    .labelsHidden()
                                    .tint(.money)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                    }

                    settingsGroup(label: "ALFIE PLUS") {
                        Button {
                            if subscriptions.isSubscribed {
                                showManageSubscriptions = true
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            settingsRow(
                                icon: "sparkles",
                                tint: .training,
                                title: subscriptions.isSubscribed ? "Manage Subscription" : "Remove Ads",
                                subtitle: subscriptions.isSubscribed ? "Subscribed — no ads" : "$3.99/mo · no ads in Nutrition or Workouts"
                            )
                        }
                    }

                    settingsGroup(label: "APP · ALFIE \(appVersionString)") {
                        HStack {
                            settingsRow(icon: "lock.shield.fill", tint: .ink, title: "Require Face ID", subtitle: nil, showChevron: false)
                            Spacer()
                            Toggle("", isOn: $authManager.isAppLockEnabled)
                                .labelsHidden()
                                .tint(.money)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)

                        Divider().overlay(Color.hairline).padding(.leading, 60)

                        HStack {
                            settingsRow(icon: "circle.lefthalf.filled", tint: .ink, title: "Appearance", subtitle: nil, showChevron: false)
                            Spacer()
                            AppearancePicker(selection: $appearanceMode)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)

                        Divider().overlay(Color.hairline).padding(.leading, 60)

                        Button { showTour = true } label: {
                            HStack {
                                settingsRow(icon: "questionmark.circle.fill", tint: .ink, title: "How to use Alfie", subtitle: nil, showChevron: false)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.inkQuaternary)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }
                    }

                    Button {
                        authManager.signOut()
                    } label: {
                        Text("Sign out")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.training)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.card)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.training.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .background(Color.paper)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .sheet(isPresented: $showTour) {
            AppTourView(trackedModules: trackedModules)
        }
        .sheet(isPresented: $showPaywall) {
            RemoveAdsPaywallView()
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }

    // MARK: - Tracked modules

    private var trackedModules: Set<TrackedModule> {
        TrackedModule.set(fromRawValue: trackedModulesRaw)
    }

    private func moduleBinding(for module: TrackedModule) -> Binding<Bool> {
        Binding(
            get: { trackedModules.contains(module) },
            set: { isOn in
                var modules = trackedModules
                if isOn {
                    modules.insert(module)
                } else if modules.count > 1 {
                    modules.remove(module)
                }
                trackedModulesRaw = TrackedModule.rawValue(from: modules)
            }
        )
    }

    // MARK: - Row helpers

    private func settingsGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
        }
    }

    private var healthStatusRow: some View {
        HStack(spacing: 12) {
            IconBadge(systemName: "heart.text.square.fill", color: .training, size: 32, shape: .roundedSquare(radius: 11))

            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Health")
                    .font(.rowTitle)
                    .foregroundStyle(Color.ink)
                Text(health.isAuthorized ? "Connected" : "Not connected")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(health.isAuthorized ? Color.money : Color.inkTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.inkQuaternary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    private func openHealthSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func settingsRow(icon: String, tint: Color, title: String, subtitle: String?, showChevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemName: icon, color: tint, size: 32, shape: .roundedSquare(radius: 11))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rowTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.rowDetail)
                        .foregroundStyle(Color.inkTertiary)
                }
            }
            .layoutPriority(1)

            if showChevron {
                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.inkQuaternary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    // MARK: - Summary strings

    private var incomeSubtitle: String {
        guard let income else { return "Not set up" }
        let amount = income.amount.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        let next = income.nextPayDate.formatted(.dateTime.month(.abbreviated).day())
        return "\(amount) \(income.cadence.displayName.lowercased()) · next \(next)"
    }

    private var billsSubtitle: String {
        guard !activeBills.isEmpty else { return "No bills yet" }
        let total = activeBills.reduce(0) { $0 + $1.amount }
        return "\(activeBills.count) bill\(activeBills.count == 1 ? "" : "s") · \(total.formatted(.currency(code: "USD").precision(.fractionLength(0)))) a month"
    }

    private var categoriesSubtitle: String {
        let spending = categories.filter { $0.type == .spending }.count
        let bill = categories.filter { $0.type == .bill }.count
        return "\(spending) spending · \(bill) bill"
    }

    private var workoutGoalsSubtitle: String {
        guard let goals = workoutGoals.first else { return "Not set up" }
        return "\(goals.weeklyStrengthGoal) strength · \(goals.weeklyCardioGoal) cardio · \(goals.weeklyStepGoal / 1000)k steps"
    }

    private var nutritionGoalsSubtitle: String {
        guard let goals = nutritionGoals.first else { return "Not set up" }
        return "\(Int(goals.calorieGoal).formatted()) cal · \(Int(goals.proteinGoalGrams))p / \(Int(goals.carbsGoalGrams))c / \(Int(goals.fatGoalGrams))f"
    }

    private var appVersionString: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(shortVersion) (\(build))"
    }
}

/// Three-way Auto/Light/Dark segmented control matching the app's card styling
/// rather than the system segmented-control appearance.
private struct AppearancePicker: View {
    @Binding var selection: AppearanceMode
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppearanceMode.allCases) { mode in
                Text(mode.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selection == mode ? Color.ink : Color.inkTertiary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background {
                        if selection == mode {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.elevated)
                                .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                                .matchedGeometryEffect(id: "appearanceSegment", in: namespace)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = mode }
                    }
            }
        }
        .padding(3)
        .background(Color.fill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
