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

    enum CodingKeys: String, CodingKey {
      case appGroupId, teamAName, teamBName, teamAScore, teamBScore
      case matchMinute, lastEventLine, lastEventIsHome, contentTick
      case chronoRunning, chronoBaseSeconds, chronoStartedAtMs, liveMinute
      case isHalftime, isExtraHalftime, isFulltime, isExtraFulltime
      case isExtraTimePlaying, lastEvent
    }

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

    /// Tolérant aux payloads plugin (bool en "1"/"true", contentTick en Double).
    public init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      appGroupId = Self.decodeString(c, .appGroupId)
      teamAName = Self.decodeString(c, .teamAName)
      teamBName = Self.decodeString(c, .teamBName)
      teamAScore = Self.decodeInt(c, .teamAScore)
      teamBScore = Self.decodeInt(c, .teamBScore)
      matchMinute = Self.decodeString(c, .matchMinute)
      lastEventLine = Self.decodeString(c, .lastEventLine)
      lastEventIsHome = Self.decodeBool(c, .lastEventIsHome, default: true)
      contentTick = Self.decodeInt(c, .contentTick)
      chronoRunning = Self.decodeBool(c, .chronoRunning)
      chronoBaseSeconds = Self.decodeInt(c, .chronoBaseSeconds)
      chronoStartedAtMs = Self.decodeInt(c, .chronoStartedAtMs)
      liveMinute = Self.decodeInt(c, .liveMinute)
      isHalftime = Self.decodeBool(c, .isHalftime)
      isExtraHalftime = Self.decodeBool(c, .isExtraHalftime)
      isFulltime = Self.decodeBool(c, .isFulltime)
      isExtraFulltime = Self.decodeBool(c, .isExtraFulltime)
      isExtraTimePlaying = Self.decodeBool(c, .isExtraTimePlaying)
      lastEvent = Self.decodeString(c, .lastEvent)
    }

    private static func decodeString(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String {
      if let s = try? c.decodeIfPresent(String.self, forKey: key) { return s }
      if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return String(i) }
      return ""
    }

    private static func decodeInt(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int {
      if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return i }
      if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(d) }
      if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Int(s) ?? 0 }
      return 0
    }

    private static func decodeBool(
      _ c: KeyedDecodingContainer<CodingKeys>,
      _ key: CodingKeys,
      default def: Bool = false
    ) -> Bool {
      if let b = try? c.decodeIfPresent(Bool.self, forKey: key) { return b }
      if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return i != 0 }
      if let s = try? c.decodeIfPresent(String.self, forKey: key) {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t == "0" || t == "false" || t == "no" { return false }
        if t == "1" || t == "true" || t == "yes" { return true }
      }
      return def
    }
  }

  public var id = UUID()
}
