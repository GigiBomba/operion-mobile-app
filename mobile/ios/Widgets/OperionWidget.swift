import WidgetKit
import SwiftUI

/// Shared App Group suite used by both widget extensions.
///
/// MUST match the `com.apple.security.application-groups` entitlement on the
/// app + extension AND the `HomeWidget.setAppGroupId(...)` call on the Dart
/// side (see `core/app/app_services.dart`).
enum OperionWidgetGroup {
  static let id = "group.com.operion.operionMobile"
}

/// "Today's KPIs" — dispatcher/manager home-screen widget.
///
/// iOS widgets cannot run Dart: data is pushed from the app via
/// `HomeWidget.saveWidgetData` (15-min Timer, push-triggered, after
/// job/alert events) into the shared App Group UserDefaults. This timeline
/// renders that last-known data. LIVE BEHAVIOR IS DEVICE-REQUIRED.
struct OperionWidgetEntry: TimelineEntry {
  let date: Date
  let activeJobs: String
  let openAlerts: String
  let revenueToDate: String
  let lastUpdated: String
}

struct OperionWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> OperionWidgetEntry {
    OperionWidgetEntry(
      date: Date(), activeJobs: "—", openAlerts: "—", revenueToDate: "—", lastUpdated: "")
  }

  func getSnapshot(
    in context: Context, completion: @escaping (OperionWidgetEntry) -> Void
  ) {
    completion(loadEntry())
  }

  func getTimeline(
    in context: Context, completion: @escaping (Timeline<OperionWidgetEntry>) -> Void
  ) {
    // The widget shows the last-known pushed data; the OS refreshes it at
    // its own cadence and the app pushes fresh data whenever the app runs.
    completion(Timeline(entries: [loadEntry()], policy: .atEnd))
  }

  private func loadEntry() -> OperionWidgetEntry {
    let defaults = UserDefaults(suiteName: OperionWidgetGroup.id)
    return OperionWidgetEntry(
      date: Date(),
      activeJobs: defaults?.string(forKey: "active_jobs") ?? "—",
      openAlerts: defaults?.string(forKey: "open_alerts") ?? "—",
      revenueToDate: defaults?.string(forKey: "revenue_to_date") ?? "—",
      lastUpdated: defaults?.string(forKey: "last_updated") ?? "")
  }
}

struct OperionWidgetView: View {
  var entry: OperionWidgetEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Operion Today")
        .font(.headline)
        .foregroundColor(.white)
      Text("Today's KPIs")
        .font(.caption2)
        .foregroundColor(.white.opacity(0.8))

      HStack {
        StatCell(label: "Active Jobs", value: entry.activeJobs)
        StatCell(label: "Open Alerts", value: entry.openAlerts)
        StatCell(label: "Revenue MTD", value: entry.revenueToDate)
      }
      .padding(.top, 2)

      if !entry.lastUpdated.isEmpty {
        Text("Updated \(entry.lastUpdated)")
          .font(.system(size: 8))
          .foregroundColor(.white.opacity(0.6))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(red: 0.10, green: 0.14, blue: 0.49))
    .widgetURL(URL(string: "operion://overview"))
  }
}

struct StatCell: View {
  let label: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.system(size: 9))
        .foregroundColor(.white.opacity(0.75))
      Text(value)
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(.white)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
