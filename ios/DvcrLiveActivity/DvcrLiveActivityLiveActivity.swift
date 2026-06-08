//
//  DvcrLiveActivityLiveActivity.swift
//  DvcrLiveActivity
//
//  Live Activity — style carte match accueil (score pill, logos, une seule ligne fait).
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

private enum DvcrLiveColors {
  static let background = Color(red: 6 / 255, green: 41 / 255, blue: 33 / 255)
  static let liveSoft = Color(red: 201 / 255, green: 65 / 255, blue: 86 / 255)
  static let gold = Color(red: 245 / 255, green: 215 / 255, blue: 110 / 255)
  static let goldDim = Color(red: 245 / 255, green: 215 / 255, blue: 110 / 255).opacity(0.55)
  static let label = Color.white.opacity(0.88)
  static let teamName = Color.white
  static let score = Color.white
  static let liveRed = Color(red: 232 / 255, green: 93 / 255, blue: 106 / 255)
  static let logoBg = Color.white
  static let monogram = Color(red: 6 / 255, green: 41 / 255, blue: 33 / 255)
}

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

    matchName = str("matchName", default: "Drapeau Vert Carton Rouge")
    teamAName = str("teamAName", default: "—")
    teamAScore = int("teamAScore")
    teamALogo = str("teamALogo")
    teamBName = str("teamBName", default: "—")
    teamBScore = int("teamBScore")
    teamBLogo = str("teamBLogo")
    let rawEvent = str("lastGoalLine").isEmpty ? str("lastEventLine") : str("lastGoalLine")
    lastEventLine = DvcrLiveFormat.compactEventLine(rawEvent)
  }
}

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

    let lastEventPhase = str("lastEvent")
    isFulltime = bool("isFulltime") || lastEventPhase == "fulltime"
    isExtraFulltime = bool("isExtraFulltime") || lastEventPhase == "extra_fulltime"
    isHalftime = bool("isHalftime") || lastEventPhase == "halftime"
    isExtraHalftime = bool("isExtraHalftime") || lastEventPhase == "extra_halftime"
    isExtraTimePlaying = bool("isExtraTimePlaying") || lastEventPhase == "extra_time"
    chronoRunning = bool("chronoRunning")
    chronoBaseSeconds = int("chronoBaseSeconds")
    chronoStartedAtMs = int("chronoStartedAtMs")
    liveMinute = int("liveMinute")
    let minuteRaw = str("matchMinute").isEmpty ? str("teamAState") : str("matchMinute")
    fallbackMinute = minuteRaw.isEmpty ? "LIVE" : minuteRaw
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
      if isExtraTimePlaying { return "P\(m)'" }
      return "\(m)'"
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
    if t.isEmpty { return "—" }
    return String(t.prefix(2)).uppercased()
  }

  static func shortTeam(_ raw: String, max: Int = 14) -> String {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.isEmpty { return "—" }
    if t.count <= max { return t.uppercased() }
    return String(t.prefix(max - 1)).uppercased() + "…"
  }

  static func footerLine(chrono: DvcrChronoState, eventLine: String, at date: Date) -> String {
    if !eventLine.isEmpty { return eventLine }
    if chrono.isFulltime || chrono.isExtraFulltime { return "Fin du match" }
    if chrono.isHalftime || chrono.isExtraHalftime { return "Mi-temps" }
    if chrono.isExtraTimePlaying { return "Prolongations" }
    if chrono.usesLiveClock || chrono.chronoRunning || chrono.liveMinute > 0 {
      return chrono.minuteLabel(at: date)
    }
    return "DIRECT"
  }
}

@available(iOSApplicationExtension 16.1, *)
struct DvcrLiveActivityLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      DvcrLiveLockScreenView(context: context)
        .activityBackgroundTint(DvcrLiveColors.background)
        .activitySystemActionForegroundColor(DvcrLiveColors.gold)
    } dynamicIsland: { context in
      let p = LiveMatchPayload(context: context)
      let chrono = DvcrChronoState(context: context)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          DvcrIslandTeamSlot(
            name: p.teamAName,
            logoPath: p.teamALogo,
            side: .leading
          )
        }
        DynamicIslandExpandedRegion(.trailing) {
          DvcrIslandTeamSlot(
            name: p.teamBName,
            logoPath: p.teamBLogo,
            side: .trailing
          )
        }
        DynamicIslandExpandedRegion(.center) {
          DvcrHomeScorePill(scoreA: p.teamAScore, scoreB: p.teamBScore, compact: true)
        }
        DynamicIslandExpandedRegion(.bottom) {
          DvcrEventFooter(chrono: chrono, eventLine: p.lastEventLine, compact: true)
            .padding(.horizontal, 8)
        }
      } compactLeading: {
        Text("\(p.teamAScore)")
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundStyle(DvcrLiveColors.gold)
      } compactTrailing: {
        Text("\(p.teamBScore)")
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundStyle(DvcrLiveColors.gold)
      } minimal: {
        DvcrHomeScorePill(scoreA: p.teamAScore, scoreB: p.teamBScore, minimal: true)
      }
      .widgetURL(URL(string: "dvcr://live"))
      .keylineTint(DvcrLiveColors.liveSoft)
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct DvcrLiveLockScreenView: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>

  var body: some View {
    let payload = LiveMatchPayload(context: context)
    let chrono = DvcrChronoState(context: context)
    let tick = sharedDefault.integer(
      forKey: context.attributes.prefixedKey("contentTick")
    )

    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        DvcrLiveChip()
        Text(payload.matchName)
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .foregroundStyle(DvcrLiveColors.label)
          .lineLimit(1)
        Spacer(minLength: 0)
      }

      HStack(alignment: .top, spacing: 6) {
        DvcrHomeTeamColumn(
          name: payload.teamAName,
          logoPath: payload.teamALogo,
          size: 48
        )
        .frame(maxWidth: .infinity)

        DvcrHomeScorePill(
          scoreA: payload.teamAScore,
          scoreB: payload.teamBScore,
          compact: false
        )
        .frame(maxWidth: .infinity)

        DvcrHomeTeamColumn(
          name: payload.teamBName,
          logoPath: payload.teamBLogo,
          size: 48
        )
        .frame(maxWidth: .infinity)
      }

      DvcrEventFooter(chrono: chrono, eventLine: payload.lastEventLine, compact: false)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(DvcrLiveColors.background)
    .id(tick)
  }
}

// MARK: - Composants style home

@available(iOSApplicationExtension 16.1, *)
private struct DvcrLiveChip: View {
  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(Color.white)
        .frame(width: 5, height: 5)
      Text("EN DIRECT")
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .kerning(0.6)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 4)
    .background(
      Capsule()
        .fill(DvcrLiveColors.liveSoft.opacity(0.88))
        .overlay(Capsule().stroke(DvcrLiveColors.liveSoft, lineWidth: 1))
    )
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct DvcrHomeScorePill: View {
  let scoreA: Int
  let scoreB: Int
  var compact: Bool = false
  var minimal: Bool = false

  var body: some View {
    HStack(spacing: minimal ? 3 : (compact ? 5 : 7)) {
      Text("\(scoreA)")
      Text("•")
        .foregroundStyle(Color.white.opacity(0.72))
        .font(.system(size: minimal ? 9 : (compact ? 14 : 20), weight: .bold))
      Text("\(scoreB)")
    }
    .font(.system(
      size: minimal ? 10 : (compact ? 17 : 24),
      weight: .bold,
      design: .rounded
    ))
    .foregroundStyle(DvcrLiveColors.score)
    .padding(.horizontal, minimal ? 6 : (compact ? 9 : 11))
    .padding(.vertical, minimal ? 3 : (compact ? 5 : 6))
    .background(
      RoundedRectangle(cornerRadius: minimal ? 10 : (compact ? 14 : 18), style: .continuous)
        .fill(DvcrLiveColors.liveSoft.opacity(0.35))
        .overlay(
          RoundedRectangle(cornerRadius: minimal ? 10 : (compact ? 14 : 18), style: .continuous)
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
      DvcrTeamLogo(name: name, logoPath: logoPath, size: size)
      Text(DvcrLiveFormat.shortTeam(name))
        .font(.system(size: 8, weight: .bold, design: .rounded))
        .foregroundStyle(DvcrLiveColors.teamName)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.75)
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct DvcrIslandTeamSlot: View {
  enum Side { case leading, trailing }

  let name: String
  let logoPath: String
  let side: Side

  var body: some View {
    HStack(spacing: 0) {
      if side == .trailing { Spacer(minLength: 0) }
      DvcrTeamLogo(name: name, logoPath: logoPath, size: 26)
      if side == .leading { Spacer(minLength: 0) }
    }
    .padding(.leading, side == .leading ? 12 : 2)
    .padding(.trailing, side == .trailing ? 12 : 2)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct DvcrEventFooter: View {
  let chrono: DvcrChronoState
  let eventLine: String
  let compact: Bool

  var body: some View {
    Group {
      if chrono.usesLiveClock && eventLine.isEmpty {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
          footer(at: timeline.date)
        }
      } else {
        footer(at: Date())
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func footer(at date: Date) -> some View {
    let text = DvcrLiveFormat.footerLine(chrono: chrono, eventLine: eventLine, at: date)
    return Text(text)
      .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
      .foregroundStyle(eventLine.isEmpty ? DvcrLiveColors.goldDim : DvcrLiveColors.gold)
      .lineLimit(1)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct DvcrTeamLogo: View {
  let name: String
  let logoPath: String
  let size: CGFloat

  var body: some View {
    Group {
      if let image = DvcrLiveImage.loadLogo(from: logoPath) {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .padding(size * 0.08)
      } else {
        Text(DvcrLiveFormat.teamInitials(name))
          .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
          .foregroundStyle(DvcrLiveColors.monogram)
      }
    }
    .frame(width: size, height: size)
    .background(DvcrLiveColors.logoBg)
    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        .stroke(DvcrLiveColors.liveSoft.opacity(0.55), lineWidth: 1.5)
    )
    .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
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
