//
//  DvcrLiveActivityLiveActivity.swift
//  DvcrLiveActivity
//
//  Live Activity — Dynamic Island avec logos, score 1|0, badge minute et ligne événement.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  /// Doit rester aligné avec `ios/Runner/LiveActivitiesAppAttributes.swift`.
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

  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    "\(id)_\(key)"
  }
}

private let sharedDefault = UserDefaults(suiteName: "group.fr.dvcr.app.liveactivities")!

// MARK: - Couleurs

private enum DvcrLiveColors {
  // Lock screen — même papier que l’app (ivoire, filet, encre).
  static let ivory        = Color(red: 244 / 255, green: 240 / 255, blue: 230 / 255)
  static let surface      = Color(red: 255 / 255, green: 253 / 255, blue: 248 / 255)
  static let hairline     = Color(red: 230 / 255, green: 224 / 255, blue: 209 / 255)
  static let border       = Color(red: 221 / 255, green: 214 / 255, blue: 198 / 255)
  static let ink          = Color(red: 10 / 255,  green: 28 / 255,  blue: 24 / 255)
  static let muted        = Color(red: 94 / 255,  green: 102 / 255, blue: 98 / 255)
  static let green        = Color(red: 10 / 255,  green: 68 / 255,  blue: 56 / 255)
  static let greenBright  = Color(red: 22 / 255,  green: 122 / 255, blue: 95 / 255)
  static let liveRed      = Color(red: 186 / 255, green: 32 / 255,  blue: 60 / 255)
  static let logoBg       = Color.white

  // Dynamic Island — fond système noir, pas d’or cheap.
  static let islandScore  = Color.white
  static let islandLabel  = Color.white.opacity(0.88)
  static let islandMuted  = Color.white.opacity(0.55)
  static let islandSep    = Color.white.opacity(0.22)

  static let background   = ivory
  static let score        = ink
  static let teamName     = ink
  static let label        = ink
  static let monogram     = green
  static let separator    = hairline
  static let gold         = green
  static let goldDim      = green.opacity(0.55)
  static let liveSoft     = liveRed
  static let islandBg     = Color(red: 10 / 255, green: 10 / 255, blue: 12 / 255)
}

// MARK: - Payload

private struct LiveMatchPayload {
  let matchName: String
  let teamAName: String
  let teamAScore: Int
  let teamALogo: String
  let teamALogoDataKey: String   // clé UserDefaults pour les bytes PNG (fallback)
  let teamBName: String
  let teamBScore: Int
  let teamBLogo: String
  let teamBLogoDataKey: String   // clé UserDefaults pour les bytes PNG (fallback)
  let lastEventLine: String
  /// Domicile → gauche ; extérieur → droite.
  let lastEventIsHome: Bool

  init(context: ActivityViewContext<LiveActivitiesAppAttributes>) {
    let state = context.state
    let useState = state.contentTick > 0

    func str(_ key: String, default def: String = "") -> String {
      sharedDefault.string(forKey: context.attributes.prefixedKey(key)) ?? def
    }
    func int(_ key: String) -> Int {
      let k = context.attributes.prefixedKey(key)
      guard let raw = sharedDefault.object(forKey: k) else { return 0 }
      if let n = raw as? NSNumber { return n.intValue }
      if let i = raw as? Int { return i }
      return sharedDefault.integer(forKey: k)
    }
    func bool(_ key: String, default def: Bool = true) -> Bool {
      let k = context.attributes.prefixedKey(key)
      guard let raw = sharedDefault.object(forKey: k) else { return def }
      if let b = raw as? Bool { return b }
      if let n = raw as? NSNumber { return n.intValue != 0 }
      if let s = raw as? String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t == "0" || t == "false" || t == "no" || t == "away" { return false }
        if t == "1" || t == "true" || t == "yes" || t == "home" { return true }
      }
      return def
    }

    matchName        = str("matchName", default: "Drapeau Vert Carton Rouge")
    // ContentState (push ActivityKit) prime sur App Group — logos restent en UserDefaults.
    teamAName        = useState && !state.teamAName.isEmpty ? state.teamAName : str("teamAName", default: "—")
    teamAScore       = useState ? state.teamAScore : int("teamAScore")
    teamALogo        = str("teamALogo")
    teamALogoDataKey = context.attributes.prefixedKey("teamALogoData")
    teamBName        = useState && !state.teamBName.isEmpty ? state.teamBName : str("teamBName", default: "—")
    teamBScore       = useState ? state.teamBScore : int("teamBScore")
    teamBLogo        = str("teamBLogo")
    teamBLogoDataKey = context.attributes.prefixedKey("teamBLogoData")
    let rawEvent: String
    if useState && !state.lastEventLine.isEmpty {
      rawEvent = state.lastEventLine
    } else {
      rawEvent = str("lastGoalLine").isEmpty ? str("lastEventLine") : str("lastGoalLine")
    }
    lastEventLine    = DvcrLiveFormat.compactEventLine(rawEvent)
    lastEventIsHome  = useState ? state.lastEventIsHome : bool("lastEventIsHome", default: true)
  }
}

// MARK: - Chrono

private struct DvcrChronoState {
  let isFulltime: Bool
  let isExtraFulltime: Bool
  let isHalftime: Bool
  let isExtraHalftime: Bool
  let isExtraTimePlaying: Bool
  let chronoRunning: Bool
  let chronoBaseSeconds: Int
  let chronoStartedAtMs: Int
  let liveMinute: Int
  let fallbackMinute: String

  init(context: ActivityViewContext<LiveActivitiesAppAttributes>) {
    let state = context.state
    let useState = state.contentTick > 0

    func str(_ key: String, default def: String = "") -> String {
      sharedDefault.string(forKey: context.attributes.prefixedKey(key)) ?? def
    }
    func int(_ key: String) -> Int {
      let k = context.attributes.prefixedKey(key)
      guard let raw = sharedDefault.object(forKey: k) else { return 0 }
      if let n = raw as? NSNumber { return n.intValue }
      if let i = raw as? Int { return i }
      return sharedDefault.integer(forKey: k)
    }
    func bool(_ key: String) -> Bool {
      let k = context.attributes.prefixedKey(key)
      guard let raw = sharedDefault.object(forKey: k) else { return false }
      if let b = raw as? Bool { return b }
      if let n = raw as? NSNumber { return n.intValue != 0 }
      if let s = raw as? String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t == "1" || t == "true" || t == "yes"
      }
      return sharedDefault.bool(forKey: k)
    }

    let lastEventPhase   = useState ? state.lastEvent : str("lastEvent")
    isFulltime           = (useState ? state.isFulltime : bool("isFulltime")) || lastEventPhase == "fulltime"
    isExtraFulltime      = (useState ? state.isExtraFulltime : bool("isExtraFulltime")) || lastEventPhase == "extra_fulltime"
    isHalftime           = (useState ? state.isHalftime : bool("isHalftime")) || lastEventPhase == "halftime"
    isExtraHalftime      = (useState ? state.isExtraHalftime : bool("isExtraHalftime")) || lastEventPhase == "extra_halftime"
    isExtraTimePlaying   = (useState ? state.isExtraTimePlaying : bool("isExtraTimePlaying")) || lastEventPhase == "extra_time"
    chronoRunning        = useState ? state.chronoRunning : bool("chronoRunning")
    chronoBaseSeconds    = useState ? state.chronoBaseSeconds : int("chronoBaseSeconds")
    chronoStartedAtMs    = useState ? state.chronoStartedAtMs : int("chronoStartedAtMs")
    liveMinute           = useState ? state.liveMinute : int("liveMinute")
    let minuteRaw: String
    if useState && !state.matchMinute.isEmpty {
      minuteRaw = state.matchMinute
    } else {
      minuteRaw = str("matchMinute").isEmpty ? str("teamAState") : str("matchMinute")
    }
    fallbackMinute       = minuteRaw.isEmpty ? "LIVE" : minuteRaw
  }

  var usesLiveClock: Bool {
    chronoRunning && !isFulltime && !isExtraFulltime && !isHalftime && !isExtraHalftime
  }

  func minuteLabel(at date: Date) -> String {
    if isFulltime || isExtraFulltime { return "FIN" }
    if isHalftime || isExtraHalftime { return "MT" }
    let fb = fallbackMinute.trimmingCharacters(in: .whitespacesAndNewlines)
    if fb == "Mi-temps" || fb == "MT" { return "MT" }
    if fb == "Fin" || fb == "FIN" { return "FIN" }
    let seconds = elapsedSeconds(at: date)
    if seconds > 0 {
      let m = seconds / 60
      return isExtraTimePlaying ? "P\(m)'" : "\(m)'"
    }
    if isExtraTimePlaying { return "PROL" }
    if liveMinute > 0 { return "\(liveMinute)'" }
    if chronoRunning { return "0'" }
    return fb.isEmpty ? "LIVE" : fb
  }

  private func elapsedSeconds(at date: Date) -> Int {
    if chronoRunning {
      if chronoStartedAtMs > 0 {
        let nowMs = Int(date.timeIntervalSince1970 * 1000)
        return chronoBaseSeconds + max(0, (nowMs - chronoStartedAtMs) / 1000)
      }
      if chronoBaseSeconds > 0 { return chronoBaseSeconds }
    }
    if chronoBaseSeconds > 0 { return chronoBaseSeconds }
    if liveMinute > 0 { return liveMinute * 60 }
    return 0
  }
}

// MARK: - Format

private enum DvcrLiveFormat {
  static func compactEventLine(_ raw: String) -> String {
    let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if line.isEmpty { return "" }
    if line.count <= 36 { return line }
    return String(line.prefix(34)) + "…"
  }

  static func teamInitials(_ name: String) -> String {
    let parts = name
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .split(whereSeparator: { $0.isWhitespace })
      .map(String.init)
      .filter { !$0.isEmpty }
    if parts.count >= 2 {
      return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
    }
    let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty ? "—" : String(t.prefix(2)).uppercased()
  }

  static func shortTeam(_ raw: String, max: Int = 12) -> String {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.isEmpty { return "—" }
    if t.count <= max { return t }
    return String(t.prefix(max - 1)) + "…"
  }
}

// MARK: - Widget entry

@available(iOSApplicationExtension 16.1, *)
struct DvcrLiveActivityLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      DvcrLiveLockScreenView(context: context)
        .activityBackgroundTint(DvcrLiveColors.ivory)
        .activitySystemActionForegroundColor(DvcrLiveColors.green)
    } dynamicIsland: { context in
      let p      = LiveMatchPayload(context: context)
      let chrono = DvcrChronoState(context: context)

      return DynamicIsland {
        // ── Expanded ─────────────────────────────────────────────────────
        DynamicIslandExpandedRegion(.leading) {
          DvcrIslandTeamBlock(
            name: p.teamAName,
            logoPath: p.teamALogo,
            side: .leading,
            dataKey: p.teamALogoDataKey
          )
        }
        DynamicIslandExpandedRegion(.trailing) {
          DvcrIslandTeamBlock(
            name: p.teamBName,
            logoPath: p.teamBLogo,
            side: .trailing,
            dataKey: p.teamBLogoDataKey
          )
        }
        DynamicIslandExpandedRegion(.center) {
          DvcrIslandScoreView(scoreA: p.teamAScore, scoreB: p.teamBScore)
        }
        DynamicIslandExpandedRegion(.bottom) {
          DvcrIslandEventBar(
            chrono: chrono,
            eventLine: p.lastEventLine,
            isHome: p.lastEventIsHome
          )
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }

      // ── Compact ──────────────────────────────────────────────────────
      } compactLeading: {
        HStack(spacing: 4) {
          DvcrTeamLogo(name: p.teamAName, logoPath: p.teamALogo, size: 18, dataKey: p.teamALogoDataKey)
          Text("\(p.teamAScore)")
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(DvcrLiveColors.islandScore)
        }
        .padding(.leading, 3)
        .clipped()

      } compactTrailing: {
        HStack(spacing: 4) {
          Text("\(p.teamBScore)")
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(DvcrLiveColors.islandScore)
          DvcrTeamLogo(name: p.teamBName, logoPath: p.teamBLogo, size: 18, dataKey: p.teamBLogoDataKey)
        }
        .padding(.trailing, 3)
        .clipped()

      // ── Minimal ──────────────────────────────────────────────────────
      } minimal: {
        Text("\(p.teamAScore)-\(p.teamBScore)")
          .font(.system(size: 11, weight: .black, design: .rounded))
          .foregroundStyle(DvcrLiveColors.islandScore)
      }
      .widgetURL(URL(string: "dvcr://live"))
      .keylineTint(DvcrLiveColors.liveRed)
    }
  }
}

// MARK: - Lock screen (style MLB card)

@available(iOSApplicationExtension 16.1, *)
private struct DvcrLiveLockScreenView: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>

  var body: some View {
    let p     = LiveMatchPayload(context: context)
    let chrono = DvcrChronoState(context: context)
    let tick  = context.state.contentTick > 0
      ? context.state.contentTick
      : sharedDefault.integer(forKey: context.attributes.prefixedKey("contentTick"))

    VStack(spacing: 0) {
      // ── Ligne principale : logo | score | minute | score | logo ──────
      HStack(alignment: .center, spacing: 0) {

        // Équipe A : logo + abrev + score
        HStack(spacing: 10) {
          DvcrTeamLogo(name: p.teamAName, logoPath: p.teamALogo, size: 52, circular: false, dataKey: p.teamALogoDataKey)
          VStack(alignment: .leading, spacing: 2) {
            Text(DvcrLiveFormat.shortTeam(p.teamAName, max: 10).uppercased())
              .font(.system(size: 9, weight: .bold, design: .rounded))
              .foregroundStyle(DvcrLiveColors.muted)
              .lineLimit(1)
            Text("\(p.teamAScore)")
              .font(.system(size: 34, weight: .black, design: .rounded))
              .foregroundStyle(DvcrLiveColors.score)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        // Centre : badge minute
        DvcrMinuteBadge(chrono: chrono)
          .frame(minWidth: 56)

        // Équipe B : score + abrev + logo
        HStack(spacing: 10) {
          VStack(alignment: .trailing, spacing: 2) {
            Text(DvcrLiveFormat.shortTeam(p.teamBName, max: 10).uppercased())
              .font(.system(size: 9, weight: .bold, design: .rounded))
              .foregroundStyle(DvcrLiveColors.muted)
              .lineLimit(1)
            Text("\(p.teamBScore)")
              .font(.system(size: 34, weight: .black, design: .rounded))
              .foregroundStyle(DvcrLiveColors.score)
          }
          DvcrTeamLogo(name: p.teamBName, logoPath: p.teamBLogo, size: 52, circular: false, dataKey: p.teamBLogoDataKey)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding(.horizontal, 14)
      .padding(.top, 12)
      .padding(.bottom, 10)

      // ── Séparateur + ligne événement (masqués si aucun fait de jeu) ─────
      if !p.lastEventLine.isEmpty {
        Rectangle()
          .fill(DvcrLiveColors.hairline)
          .frame(height: 1)
        DvcrLockEventBar(
          chrono: chrono,
          eventLine: p.lastEventLine,
          isHome: p.lastEventIsHome
        )
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
      }
    }
    .background(DvcrLiveColors.background)
    .id(tick)
  }
}

/// Badge minute central — juste la minute, rien quand le chrono n'a pas démarré.
@available(iOSApplicationExtension 16.1, *)
private struct DvcrMinuteBadge: View {
  let chrono: DvcrChronoState

  var body: some View {
    Group {
      if chrono.usesLiveClock {
        TimelineView(.periodic(from: .now, by: 1.0)) { tl in
          badge(label: chrono.minuteLabel(at: tl.date))
        }
      } else {
        badge(label: chrono.minuteLabel(at: .now))
      }
    }
  }

  private func badge(label: String) -> some View {
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    // Rien avant le coup d'envoi (LIVE ou vide)
    let empty = trimmed.isEmpty || trimmed == "LIVE"
    return Group {
      if !empty {
        Text(trimmed)
          .font(.system(size: 13, weight: .black, design: .rounded))
          .foregroundStyle(Color.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
              .fill(DvcrLiveColors.green)
          )
      } else {
        Color.clear.frame(width: 1, height: 1)
      }
    }
  }
}

// MARK: - Dynamic Island expanded components

/// Bloc équipe — logo circulaire + nom, côté leading ou trailing.
@available(iOSApplicationExtension 16.1, *)
private struct DvcrIslandTeamBlock: View {
  enum Side { case leading, trailing }
  let name: String
  let logoPath: String
  let side: Side
  var dataKey: String? = nil

  var body: some View {
    VStack(spacing: 4) {
      DvcrTeamLogo(name: name, logoPath: logoPath, size: 36, circular: true, dataKey: dataKey)
      Text(DvcrLiveFormat.shortTeam(name, max: 10))
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .foregroundStyle(DvcrLiveColors.islandLabel)
        .lineLimit(2)
        .multilineTextAlignment(side == .leading ? .leading : .trailing)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: side == .leading ? .leading : .trailing)
    .padding(.leading, side == .leading ? 6 : 2)
    .padding(.trailing, side == .trailing ? 6 : 2)
    .clipped()
  }
}

/// Score style `1 | 0` pour le Dynamic Island expanded.
@available(iOSApplicationExtension 16.1, *)
private struct DvcrIslandScoreView: View {
  let scoreA: Int
  let scoreB: Int

  var body: some View {
    HStack(spacing: 0) {
      Text("\(scoreA)")
        .font(.system(size: 32, weight: .black, design: .rounded))
        .foregroundStyle(DvcrLiveColors.islandScore)
        .frame(minWidth: 28, alignment: .trailing)

      Rectangle()
        .fill(DvcrLiveColors.islandSep)
        .frame(width: 1.5, height: 28)
        .padding(.horizontal, 10)

      Text("\(scoreB)")
        .font(.system(size: 32, weight: .black, design: .rounded))
        .foregroundStyle(DvcrLiveColors.islandScore)
        .frame(minWidth: 28, alignment: .leading)
    }
  }
}

/// Barre événement expanded — minute en capsule + ligne fait de jeu (rien si pas d'événement).
/// Alignée à gauche (domicile) ou à droite (extérieur).
@available(iOSApplicationExtension 16.1, *)
private struct DvcrIslandEventBar: View {
  let chrono: DvcrChronoState
  let eventLine: String
  var isHome: Bool = true

  var body: some View {
    Group {
      if chrono.usesLiveClock {
        TimelineView(.periodic(from: .now, by: 1.0)) { tl in
          bar(minuteLabel: chrono.minuteLabel(at: tl.date))
        }
      } else {
        bar(minuteLabel: chrono.minuteLabel(at: .now))
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func bar(minuteLabel: String) -> some View {
    let trimmed = minuteLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    let showMinute = !trimmed.isEmpty && trimmed != "LIVE"
    return HStack(spacing: 8) {
      if !isHome { Spacer(minLength: 0) }

      if showMinute {
        Text(trimmed)
          .font(.system(size: 10, weight: .black, design: .rounded))
          .foregroundStyle(.white)
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(Capsule().fill(DvcrLiveColors.liveRed))
      }

      if !eventLine.isEmpty {
        if showMinute {
          Rectangle()
            .fill(DvcrLiveColors.liveRed.opacity(0.6))
            .frame(width: 1.5, height: 14)
        }
        Text(eventLine)
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundStyle(DvcrLiveColors.islandLabel)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
          .multilineTextAlignment(isHome ? .leading : .trailing)
      }

      if isHome { Spacer(minLength: 0) }
    }
  }
}

// MARK: - Lock screen components

/// Score pill lock screen — `1 • 0` avec fond teinté.
@available(iOSApplicationExtension 16.1, *)
private struct DvcrHomeScorePill: View {
  let scoreA: Int
  let scoreB: Int

  var body: some View {
    HStack(spacing: 7) {
      Text("\(scoreA)")
      Text("•")
        .foregroundStyle(Color.white.opacity(0.72))
        .font(.system(size: 20, weight: .bold))
      Text("\(scoreB)")
    }
    .font(.system(size: 24, weight: .bold, design: .rounded))
    .foregroundStyle(DvcrLiveColors.score)
    .padding(.horizontal, 11)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(DvcrLiveColors.liveSoft.opacity(0.35))
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(DvcrLiveColors.liveSoft.opacity(0.65), lineWidth: 1.2)
        )
    )
    .shadow(color: DvcrLiveColors.liveSoft.opacity(0.22), radius: 6, y: 2)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct DvcrHomeTeamColumn: View {
  let name: String
  let logoPath: String
  let size: CGFloat
  var dataKey: String? = nil

  var body: some View {
    VStack(spacing: 6) {
      DvcrTeamLogo(name: name, logoPath: logoPath, size: size, circular: true, dataKey: dataKey)
      Text(DvcrLiveFormat.shortTeam(name))
        .font(.system(size: 8, weight: .bold, design: .rounded))
        .foregroundStyle(DvcrLiveColors.teamName)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.75)
    }
  }
}

/// Barre événement lock screen — domicile à gauche, extérieur à droite.
@available(iOSApplicationExtension 16.1, *)
private struct DvcrLockEventBar: View {
  let chrono: DvcrChronoState
  let eventLine: String
  var isHome: Bool = true

  var body: some View {
    Group {
      if !eventLine.isEmpty {
        HStack(spacing: 0) {
          if !isHome { Spacer(minLength: 0) }
          Text(eventLine)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(DvcrLiveColors.label)
            .lineLimit(1)
            .multilineTextAlignment(isHome ? .leading : .trailing)
          if isHome { Spacer(minLength: 0) }
        }
      } else {
        // Rien quand pas de fait de jeu
        Color.clear.frame(height: 1)
      }
    }
  }
}

// MARK: - Logo équipe

@available(iOSApplicationExtension 16.1, *)
private struct DvcrTeamLogo: View {
  let name: String
  let logoPath: String
  let size: CGFloat
  var circular: Bool = false
  var dataKey: String? = nil   // clé UserDefaults bytes PNG (fallback)

  private var cornerRadius: CGFloat { circular ? size / 2 : 6 }

  var body: some View {
    Group {
      if let image = DvcrLiveImage.loadLogo(from: logoPath, dataKey: dataKey) {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .padding(size * 0.08)
      } else {
        Text(DvcrLiveFormat.teamInitials(name))
          .font(.system(size: size * 0.30, weight: .bold, design: .rounded))
          .foregroundStyle(DvcrLiveColors.monogram)
      }
    }
    .frame(width: size, height: size)
    .background(DvcrLiveColors.logoBg)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .stroke(DvcrLiveColors.border, lineWidth: 1)
    )
  }
}

private enum DvcrLiveImage {
  /// Charge le logo d'une équipe.
  /// Stratégie (ordre de priorité) :
  ///  1. UIImage(contentsOfFile: path) — fichier écrit par writeLogoFile
  ///  2. UIImage(data:) depuis les bytes stockés dans UserDefaults sous logoKey+"Data"
  /// Les deux clés sont synchronisées par writeLogoFile avant la render du widget.
  static func loadLogo(
    from path: String,
    dataKey: String? = nil
  ) -> UIImage? {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty, let image = UIImage(contentsOfFile: trimmed),
       image.size.width >= 1 && image.size.height >= 1 {
      return image
    }
    if let key = dataKey,
       let data = sharedDefault.data(forKey: key),
       let image = UIImage(data: data),
       image.size.width >= 1 && image.size.height >= 1 {
      return image
    }
    return nil
  }
}
