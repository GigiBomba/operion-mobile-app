import WidgetKit
import SwiftUI

/// "Next stop / active trip" — driver role home-screen widget.
///
/// Data is pushed from the app into the shared App Group UserDefaults by
/// `WidgetDataService.refreshDriverTrip`. LIVE BEHAVIOR IS DEVICE-REQUIRED.
struct OperionDriverWidgetEntry: TimelineEntry {
  let date: Date
  let activeTrip: String
  let nextStop: String
}

struct OperionDriverWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> OperionDriverWidgetEntry {
    OperionDriverWidgetEntry(date: Date(), activeTrip: "No active trip", nextStop: "—")
  }

  func getSnapshot(
    in context: Context, completion: @escaping (OperionDriverWidgetEntry) -> Void
  ) {
    completion(loadEntry())
  }

  func getTimeline(
    in context: Context, completion: @escaping (Timeline<OperionDriverWidgetEntry>) -> Void
  ) {
    completion(Timeline(entries: [loadEntry()], policy: .atEnd))
  }

  private func loadEntry() -> OperionDriverWidgetEntry {
    let defaults = UserDefaults(suiteName: OperionWidgetGroup.id)
    return OperionDriverWidgetEntry(
      date: Date(),
      activeTrip: defaults?.string(forKey: "active_trip") ?? "No active trip",
      nextStop: defaults?.string(forKey: "next_stop") ?? "—")
  }
}

struct OperionDriverWidgetView: View {
  var entry: OperionDriverWidgetEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Operion Trip")
        .font(.headline)
        .foregroundColor(.white)
      Text(entry.activeTrip)
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(.white)
      Text("NEXT STOP")
        .font(.system(size: 9))
        .foregroundColor(.white.opacity(0.75))
      Text(entry.nextStop)
        .font(.system(size: 13))
        .foregroundColor(.white)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(red: 0.10, green: 0.14, blue: 0.49))
    .widgetURL(URL(string: "operion://trip"))
  }
}

@main
struct OperionWidgetsBundle: WidgetBundle {
  var body: some Widget {
    OperionWidget()
    OperionDriverWidget()
  }
}

struct OperionWidget: Widget {
  let kind: String = "OperionWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: OperionWidgetProvider()) { entry in
      OperionWidgetView(entry: entry)
    }
    .configurationDisplayName("Operion Today")
    .description("Today's KPIs — active jobs, open alerts, revenue to date.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct OperionDriverWidget: Widget {
  let kind: String = "OperionDriverWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: OperionDriverWidgetProvider()) { entry in
      OperionDriverWidgetView(entry: entry)
    }
    .configurationDisplayName("Operion Trip")
    .description("Your active trip and next stop.")
    .supportedFamilies([.systemSmall])
  }
}
