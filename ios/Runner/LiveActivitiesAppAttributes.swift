import ActivityKit
import Foundation

/// Type partagé Runner ↔ LiveActivityFcmSync.
/// Doit correspondre exactement à la définition du widget extension.
@available(iOS 16.1, *)
public struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {
    var appGroupId: String
  }

  public var id = UUID()
}
