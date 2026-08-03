import ActivityKit
import Foundation

/// Type partagé Runner ↔ LiveActivityFcmSync ↔ Widget.
/// ContentState porte le score / minute / événement pour les mises à jour
/// ActivityKit push (`apns-push-type: liveactivity`) sans réveiller l’app.
@available(iOS 16.1, *)
public struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {
    var appGroupId: String = ""
    var teamAName: String = ""
    var teamBName: String = ""
    var teamAScore: Int = 0
    var teamBScore: Int = 0
    var matchMinute: String = ""
    var lastEventLine: String = ""
    /// true = domicile (gauche), false = extérieur (droite).
    var lastEventIsHome: Bool = true
    var contentTick: Int = 0
    var chronoRunning: Bool = false
    var chronoBaseSeconds: Int = 0
    var chronoStartedAtMs: Int = 0
    var liveMinute: Int = 0
    var isHalftime: Bool = false
    var isExtraHalftime: Bool = false
    var isFulltime: Bool = false
    var isExtraFulltime: Bool = false
    var isExtraTimePlaying: Bool = false
    var lastEvent: String = ""

    public init(
      appGroupId: String = "",
      teamAName: String = "",
      teamBName: String = "",
      teamAScore: Int = 0,
      teamBScore: Int = 0,
      matchMinute: String = "",
      lastEventLine: String = "",
      lastEventIsHome: Bool = true,
      contentTick: Int = 0,
      chronoRunning: Bool = false,
      chronoBaseSeconds: Int = 0,
      chronoStartedAtMs: Int = 0,
      liveMinute: Int = 0,
      isHalftime: Bool = false,
      isExtraHalftime: Bool = false,
      isFulltime: Bool = false,
      isExtraFulltime: Bool = false,
      isExtraTimePlaying: Bool = false,
      lastEvent: String = ""
    ) {
      self.appGroupId = appGroupId
      self.teamAName = teamAName
      self.teamBName = teamBName
      self.teamAScore = teamAScore
      self.teamBScore = teamBScore
      self.matchMinute = matchMinute
      self.lastEventLine = lastEventLine
      self.lastEventIsHome = lastEventIsHome
      self.contentTick = contentTick
      self.chronoRunning = chronoRunning
      self.chronoBaseSeconds = chronoBaseSeconds
      self.chronoStartedAtMs = chronoStartedAtMs
      self.liveMinute = liveMinute
      self.isHalftime = isHalftime
      self.isExtraHalftime = isExtraHalftime
      self.isFulltime = isFulltime
      self.isExtraFulltime = isExtraFulltime
      self.isExtraTimePlaying = isExtraTimePlaying
      self.lastEvent = lastEvent
    }

    /// Tolérant aux payloads plugin (appGroupId seul) et aux pushes partiels.
    public init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      appGroupId = try c.decodeIfPresent(String.self, forKey: .appGroupId) ?? ""
      teamAName = try c.decodeIfPresent(String.self, forKey: .teamAName) ?? ""
      teamBName = try c.decodeIfPresent(String.self, forKey: .teamBName) ?? ""
      teamAScore = try c.decodeIfPresent(Int.self, forKey: .teamAScore) ?? 0
      teamBScore = try c.decodeIfPresent(Int.self, forKey: .teamBScore) ?? 0
      matchMinute = try c.decodeIfPresent(String.self, forKey: .matchMinute) ?? ""
      lastEventLine = try c.decodeIfPresent(String.self, forKey: .lastEventLine) ?? ""
      lastEventIsHome = try c.decodeIfPresent(Bool.self, forKey: .lastEventIsHome) ?? true
      contentTick = try c.decodeIfPresent(Int.self, forKey: .contentTick) ?? 0
      chronoRunning = try c.decodeIfPresent(Bool.self, forKey: .chronoRunning) ?? false
      chronoBaseSeconds = try c.decodeIfPresent(Int.self, forKey: .chronoBaseSeconds) ?? 0
      chronoStartedAtMs = try c.decodeIfPresent(Int.self, forKey: .chronoStartedAtMs) ?? 0
      liveMinute = try c.decodeIfPresent(Int.self, forKey: .liveMinute) ?? 0
      isHalftime = try c.decodeIfPresent(Bool.self, forKey: .isHalftime) ?? false
      isExtraHalftime = try c.decodeIfPresent(Bool.self, forKey: .isExtraHalftime) ?? false
      isFulltime = try c.decodeIfPresent(Bool.self, forKey: .isFulltime) ?? false
      isExtraFulltime = try c.decodeIfPresent(Bool.self, forKey: .isExtraFulltime) ?? false
      isExtraTimePlaying = try c.decodeIfPresent(Bool.self, forKey: .isExtraTimePlaying) ?? false
      lastEvent = try c.decodeIfPresent(String.self, forKey: .lastEvent) ?? ""
    }
  }

  public var id = UUID()
}
