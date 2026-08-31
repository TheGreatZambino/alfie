import SwiftUI

/// Standalone replay of the "how to use the app" tour, reusing the same pages shown at the
/// end of first-run onboarding. Presented as a sheet from Settings.
struct AppTourView: View {
    @Environment(\.dismiss) private var dismiss
    let trackedModules: Set<TrackedModule>

    @State private var pageIndex = 0

    private var pages: [TourPage] { TourPage.pages(for: trackedModules) }
    private var isLastPage: Bool { pageIndex == pages.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar

                ScrollView {
                    VStack(spacing: 0) {
                        TourPageView(page: pages[pageIndex])
                        if isLastPage {
                            SupportAlfieSection()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
                }

                footer
            }
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<pages.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index <= pageIndex ? Color.money : Color.ink.opacity(0.10))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Button {
                if isLastPage {
                    dismiss()
                } else {
                    pageIndex += 1
                }
            } label: {
                Text(isLastPage ? "Done" : "Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.moneyFill)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.moneyFill.opacity(0.28), radius: 10, y: 8)
            }

            if !isLastPage {
                Button("Skip") { dismiss() }
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
    }
}
