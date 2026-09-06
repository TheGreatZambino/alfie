import AppIntents
import WidgetKit

/// The set of sections a user can place in a row of the Overview widget.
enum HomeWidgetSection: String, AppEnum {
    case finance
    case nutrition
    case workouts
    case water
    case none

    nonisolated(unsafe) static var typeDisplayRepresentation: TypeDisplayRepresentation = "Section"

    nonisolated(unsafe) static var caseDisplayRepresentations: [HomeWidgetSection: DisplayRepresentation] = [
        .finance: DisplayRepresentation(title: "Finances"),
        .nutrition: DisplayRepresentation(title: "Nutrition"),
        .workouts: DisplayRepresentation(title: "Workouts"),
        .water: DisplayRepresentation(title: "Water"),
        .none: DisplayRepresentation(title: "Hidden")
    ]
}

/// Lets the user pick which section shows in each row of the Overview widget, and in what order,
/// via the widget's "Edit Widget" configuration UI.
struct HomeWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Overview Sections"
    static var description = IntentDescription("Choose what shows in each row of the Overview widget.")

    @Parameter(title: "Row 1", default: .finance)
    var topSection: HomeWidgetSection

    @Parameter(title: "Row 2", default: .water)
    var secondSection: HomeWidgetSection

    @Parameter(title: "Row 3", default: .nutrition)
    var thirdSection: HomeWidgetSection

    @Parameter(title: "Row 4", default: .workouts)
    var bottomSection: HomeWidgetSection

    /// All four configured rows in order, hidden ones removed. Used by the large widget, which
    /// has room for all of them.
    var orderedSections: [HomeWidgetSection] {
        [topSection, secondSection, thirdSection, bottomSection].filter { $0 != .none }
    }

    /// Rows 1, 3, and 4 only — Row 2 is skipped so the medium widget's default composition
    /// (Finance/Nutrition/Workouts) is unaffected by adding a fourth, Water-by-default row.
    var compactSections: [HomeWidgetSection] {
        [topSection, thirdSection, bottomSection].filter { $0 != .none }
    }
}
