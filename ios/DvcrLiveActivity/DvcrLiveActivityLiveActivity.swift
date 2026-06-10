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

  public struct ContentState: Codable, Hashable {}

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
  static let background   = Color(red: 6 / 255,   green: 41 / 255,  blue: 33 / 255)
  static let islandBg     = Color(red: 10 / 255,  green: 10 / 255,  blue: 12 / 255)
  static let liveSoft     = Color(red: 201 / 255, green: 65 / 255,  blue: 86 / 255)
  static let gold         = Color(red: 245 / 255, green: 215 / 255, blue: 110 / 255)
  static let goldDim      = Color(red: 245 / 255, green: 215 / 255, blue: 110 / 255).opacity(0.55)
  static let label        = Color.white.opacity(0.88)
  static let teamName     = Color.white
  static let score        = Color.white
  static let liveRed      = Color(red: 232 / 255, green: 93 / 255,  blue: 106 / 255)
  static let logoBg       = Color.white
  static let monogram     = Color(red: 6 / 255,   green: 41 / 255,  blue: 33 / 255)
  static let separator    = Color.white.opacity(0.25)
}

// MARK: - Payload

private struct LiveMatchPayload {
  let matchName: String
  let teamAName: String
  let teamAScore: Int
  let teamALogo: String
  let teamBName: String
  let teamBScore: Int
  let teamBLogo: String
  let lastEventLine: String

  init(context: ActivityViewContext<LiveActivitiesAppAttributes>) {
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

    matchName    = str("matchName", default: "Drapeau Vert Carton Rouge")
    teamAName    = str("teamAName", default: "—")
    teamAScore   = int("teamAScore")
    teamALogo    = str("teamALogo")
    teamBName    = str("teamBName", default: "—")
    teamBScore   = int("teamBScore")
    teamBLogo    = str("teamBLogo")
    let rawEvent = str("lastGoalLine").isEmpty ? str("lastEventLine") : str("lastGoalLine")
    lastEventLine = DvcrLiveFormat.compactEventLine(rawEvent)
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

    let lastEventPhase   = str("lastEvent")
    isFulltime           = bool("isFulltime")      || lastEventPhase == "fulltime"
    isExtraFulltime      = bool("isExtraFulltime") || lastEventPhase == "extra_fulltime"
    isHalftime           = bool("isHalftime")      || lastEventPhase == "halftime"
    isExtraHalftime      = bool("isExtraHalftime") || lastEventPhase == "extra_halftime"
    isExtraTimePlaying   = bool("isExtraTimePlaying") || lastEventPhase == "extra_time"
    chronoRunning        = bool("chronoRunning")
    chronoBaseSeconds    = int("chronoBaseSeconds")
    chronoStartedAtMs    = int("chronoStartedAtMs")
    liveMinute           = int("liveMinute")
    let minuteRaw        = str("matchMinute").isEmpty ? str("teamAState") : str("matchMinute")
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
        .activityBackgroundTint(DvcrLiveColors.background)
        .activitySystemActionForegroundColor(DvcrLiveColors.gold)
    } dynamicIsland: { context in
      let p      = LiveMatchPayload(context: context)
      let chrono = DvcrChronoState(context: context)

      return DynamicIsland {
        // ── Expanded ─────────────────────────────────────────────────────
        DynamicIslandExpandedRegion(.leading) {
          DvcrIslandTeamBlock(
            name: p.teamAName,
            logoPath: p.teamALogo,
            side: .leading
          )
        }
        DynamicIslandExpandedRegion(.trailing) {
          DvcrIslandTeamBlock(
            name: p.teamBName,
            logoPath: p.teamBLogo,
            side: .trailing
          )
        }
        DynamicIslandExpandedRegion(.center) {
          DvcrIslandScoreView(scoreA: p.teamAScore, scoreB: p.teamBScore)
        }
        DynamicIslandExpandedRegion(.bottom) {
          DvcrIslandEventBar(chrono: chrono, eventLine: p.lastEventLine)
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }

      // ── Compact ──────────────────────────────────────────────────────
      } compactLeading: {
        HStack(spacing: 5) {
          DvcrTeamLogo(name: p.teamAName, logoPath: p.teamALogo, size: 20)
          Text("\(p.teamAScore)")
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(DvcrLiveColors.gold)
        }
        .padding(.leading, 4)

      } compactTrailing: {
        HStack(spacing: 5) {
          Text("\(p.teamBScore)")
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(DvcrLiveColors.gold)
          DvcrTeamLogo(name: p.teamBName, logoPath: p.teamBLogo, size: 20)
        }
        .padding(.trailing, 4)

      // ── Minimal ──────────────────────────────────────────────────────
      } minimal: {
        Text("\(p.teamAScore)-\(p.teamBScore)")
          .font(.system(size: 11, weight: .black, design: .rounded))
          .foregroundStyle(DvcrLiveColors.gold)
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
    let tick  = sharedDefault.integer(forKey: context.attributes.prefixedKey("contentTick"))

    VStack(spacing: 0) {
      // ── Ligne principale : logo | score | minute | score | logo ──────
      HStack(alignment: .center, spacing: 0) {

        // Équipe A : logo + abrev + score
        HStack(spacing: 10) {
          DvcrTeamLogo(name: p.teamAName, logoPath: p.teamALogo, size: 52, circular: false)
          VStack(alignment: .leading, spacing: 2) {
            Text(DvcrLiveFormat.shortTeam(p.teamAName, max: 10).uppercased())
              .font(.system(size: 9, weight: .bold, design: .rounded))
              .foregroundStyle(Color.white.opacity(0.6))
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
              .foregroundStyle(Color.white.opacity(0.6))
              .lineLimit(1)
            Text("\(p.teamBScore)")
              .font(.system(size: 34, weight: .black, design: .rounded))
              .foregroundStyle(DvcrLiveColors.score)
          }
          DvcrTeamLogo(name: p.teamBName, logoPath: p.teamBLogo, size: 52, circular: false)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding(.horizontal, 14)
      .padding(.top, 12)
      .padding(.bottom, 10)

      // ── Séparateur + ligne événement (masqués si aucun fait de jeu) ─────
      if !p.lastEventLine.isEmpty {
        Rectangle()
          .fill(Color.white.opacity(0.1))
          .frame(height: 1)
        DvcrLockEventBar(chrono: chrono, eventLine: p.lastEventLine)
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
          .font(.system(size: 15, weight: .black, design: .rounded))
          .foregroundStyle(DvcrLiveColors.gold)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .fill(Color.white.opacity(0.07))
              .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                  .stroke(Color.white.opacity(0.12), lineWidth: 1)
              )
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

  var body: some View {
    VStack(spacing: 5) {
      DvcrTeamLogo(name: name, logoPath: logoPath, size: 44, circular: true)
      Text(DvcrLiveFormat.shortTeam(name))
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .foregroundStyle(DvcrLiveColors.teamName)
        .lineLimit(2)
        .multilineTextAlignment(side == .leading ? .leading : .trailing)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: side == .leading ? .leading : .trailing)
    .padding(.leading, side == .leading ? 14 : 4)
    .padding(.trailing, side == .trailing ? 14 : 4)
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
        .foregroundStyle(DvcrLiveColors.score)
        .frame(minWidth: 28, alignment: .trailing)

      Rectangle()
        .fill(DvcrLiveColors.separator)
        .frame(width: 1.5, height: 28)
        .padding(.horizontal, 10)

      Text("\(scoreB)")
        .font(.system(size: 32, weight: .black, design: .rounded))
        .foregroundStyle(DvcrLiveColors.score)
        .frame(minWidth: 28, alignment: .leading)
    }
  }
}

/// Barre événement expanded — minute en capsule + ligne fait de jeu (rien si pas d'événement).
@available(iOSApplicationExtension 16.1, *)
private struct DvcrIslandEventBar: View {
  let chrono: DvcrChronoState
  let eventLine: String

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
          .foregroundStyle(DvcrLiveColors.label)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
      }
      Spacer(minLength: 0)
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

  var body: some View {
    VStack(spacing: 6) {
      DvcrTeamLogo(name: name, logoPath: logoPath, size: size, circular: true)
      Text(DvcrLiveFormat.shortTeam(name))
        .font(.system(size: 8, weight: .bold, design: .rounded))
        .foregroundStyle(DvcrLiveColors.teamName)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.75)
    }
  }
}

/// Barre événement lock screen — affiche le fait de jeu seulement si présent, rien sinon.
@available(iOSApplicationExtension 16.1, *)
private struct DvcrLockEventBar: View {
  let chrono: DvcrChronoState
  let eventLine: String

  var body: some View {
    Group {
      if !eventLine.isEmpty {
        HStack(spacing: 0) {
          Text(eventLine)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(DvcrLiveColors.label)
            .lineLimit(1)
          Spacer(minLength: 0)
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

  private var cornerRadius: CGFloat { circular ? size / 2 : size * 0.22 }

  var body: some View {
    Group {
      if let image = DvcrLiveImage.loadLogo(from: logoPath) {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          // Le logo a déjà un fond blanc intégré — on le laisse respirer
          .padding(size * 0.08)
      } else {
        Text(DvcrLiveFormat.teamInitials(name))
          .font(.system(size: size * 0.30, weight: .bold, design: .rounded))
          .foregroundStyle(DvcrLiveColors.monogram)
      }
    }
    .frame(width: size, height: size)
    // Fond blanc pour les logos (qui ont déjà un bg blanc, ça unifie)
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    // Bordure grise fine pour détacher le cadre blanc du fond sombre
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
    )
    .shadow(color: Color.black.opacity(0.25), radius: 5, y: 2)
  }
}

private enum DvcrLiveImage {
  static func loadLogo(from path: String) -> UIImage? {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    guard let image = UIImage(contentsOfFile: trimmed) else { return nil }
    if image.size.width < 1 || image.size.height < 1 { return nil }
    return image
  }
}
