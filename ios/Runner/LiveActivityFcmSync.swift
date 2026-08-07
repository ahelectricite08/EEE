import ActivityKit
import CryptoKit
import Flutter
import Foundation
import UIKit
import UserNotifications

/// Met à jour la Live Activity à la réception FCM — sans passer par Flutter (app suspendue).
enum LiveActivityFcmSync {
  private static let appGroupId = "group.fr.dvcr.app.liveactivities"
  private static let logicalActivityId = "dvcr_live_match"
  private static let brandName = "Drapeau Vert Carton Rouge"
  private static let keyPrefix = "dvcr_la_key_prefix"
  private static let runningIdKey = "dvcr_la_running_id"

  private static let syncTypes: Set<String> = [
    "live_sync", "goal", "yellow", "red", "substitution", "kickoff", "live_start",
    "halftime", "fulltime", "extra_time", "extra_halftime", "extra_fulltime",
    "goal_cancelled", "goal_disallowed", "offside", "yellow_card", "red_card",
  ]

  static func registerChannel(registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "fr.dvcr.app/live_activity_native",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "mirrorSnapshot" {
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "ARGS", message: "invalid args", details: nil))
          return
        }
        mirrorSnapshot(args: args)
        result(nil)
        return
      }
      if call.method == "endLiveActivity" {
        if #available(iOS 16.1, *) {
          Task { _ = await endAllLiveActivities() }
        }
        result(nil)
        return
      }
      if call.method == "getLogoPaths" {
        guard let shared = UserDefaults(suiteName: appGroupId),
              let prefix = shared.string(forKey: keyPrefix) else {
          result(["logo1": "", "logo2": ""])
          return
        }
        let logo1 = shared.string(forKey: "\(prefix)_teamALogo") ?? ""
        let logo2 = shared.string(forKey: "\(prefix)_teamBLogo") ?? ""
        result(["logo1": logo1, "logo2": logo2])
        return
      }
      if call.method == "hasActiveLiveActivity" {
        if #available(iOS 16.1, *) {
          Task {
            result(await resolvePluginActivity() != nil)
          }
        } else {
          result(false)
        }
        return
      }
      // Double sécurité logo :
      // 1) Écrit le fichier PNG dans le conteneur AppGroup (chemin dans UserDefaults)
      // 2) Stocke AUSSI les bytes PNG directement dans UserDefaults sous logoKey+"Data"
      // Le widget essaie d'abord UIImage(contentsOfFile:), puis UIImage(data:).
      // Les deux clés sont synchronisées AVANT que le plugin crée/mette à jour
      // l'activité, garantissant que le widget les voit dès la première render.
      if call.method == "writeLogoFile" {
        guard
          let args      = call.arguments as? [String: Any],
          let fileName  = args["fileName"] as? String,
          let logoKey   = args["logoKey"]  as? String,
          let typedData = args["bytes"]    as? FlutterStandardTypedData
        else { result(""); return }

        guard #available(iOS 16.1, *),
              let shared = UserDefaults(suiteName: appGroupId)
        else { result(""); return }

        let prefix = uuid5(name: logicalActivityId).uuidString
        let imgData = typedData.data

        // ── 1. Stocker les bytes directement dans UserDefaults ────────────
        shared.set(imgData, forKey: "\(prefix)_\(logoKey)Data")

        // ── 2. Écrire le fichier dans AppGroup ────────────────────────────
        var filePath = ""
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId) {
          let filesDir = containerURL.appendingPathComponent("LiveActivitiesFiles")
          try? FileManager.default.createDirectory(
            at: filesDir, withIntermediateDirectories: true, attributes: nil)
          let fileURL = filesDir.appendingPathComponent(fileName)
          if (try? imgData.write(to: fileURL, options: .atomic)) != nil {
            filePath = fileURL.path
            shared.set(filePath, forKey: "\(prefix)_\(logoKey)")
          }
        }

        shared.synchronize()
        result(filePath)
        return
      }
      // Push d'une mise à jour depuis Flutter (app au premier plan / background actif).
      // Le plugin live_activities appelle activity.update() avec un ContentState
      // CONSTANT (appGroupId seul) → iOS dédoublonne et ne re-render pas le widget.
      // Ici on écrit les données + synchronize(), puis on update avec un staleDate
      // qui change à chaque appel : ActivityContent diffère → re-render garanti.
      if call.method == "pushUpdate" {
        guard let args = call.arguments as? [String: Any],
              let data = args["data"] as? [String: Any]
        else { result(false); return }

        guard #available(iOS 16.1, *) else { result(false); return }

        let alertTitle = (args["alertTitle"] as? String ?? "")
          .trimmingCharacters(in: .whitespacesAndNewlines)
        let alertBody = (args["alertBody"] as? String ?? "")
          .trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
          let ok = await pushUpdateFromFlutter(
            data: data, alertTitle: alertTitle, alertBody: alertBody)
          result(ok)
        }
        return
      }
      result(FlutterMethodNotImplemented)
    }
  }

  /// Écrit le payload dans UserDefaults (+ synchronize) puis force un re-render
  /// du widget via un staleDate changeant. Retourne false si aucune activité.
  @available(iOS 16.1, *)
  private static func pushUpdateFromFlutter(
    data: [String: Any],
    alertTitle: String,
    alertBody: String
  ) async -> Bool {
    guard let shared = UserDefaults(suiteName: appGroupId) else { return false }

    let activities = await MainActor.run {
      Activity<LiveActivitiesAppAttributes>.activities.filter { isUsableState($0.activityState) }
    }
    guard !activities.isEmpty else { return false }

    for activity in activities {
      let prefix = activity.attributes.id
      for (key, value) in data {
        if value is NSNull {
          shared.removeObject(forKey: "\(prefix)_\(key)")
        } else {
          shared.set(value, forKey: "\(prefix)_\(key)")
        }
      }
      shared.set(prefix.uuidString, forKey: keyPrefix)
      shared.set(activity.id, forKey: runningIdKey)
    }
    shared.synchronize()

    for activity in activities {
      // activity.content is iOS 16.2+; keep a nil previous on 16.1.
      let previous: LiveActivitiesAppAttributes.ContentState?
      if #available(iOS 16.2, *) {
        previous = activity.content.state
      } else {
        previous = nil
      }
      let state = contentState(
        from: data,
        tick: Int(Date().timeIntervalSince1970 * 1000),
        previous: previous
      )
      if #available(iOS 16.2, *) {
        var alertConfig: AlertConfiguration?
        let unlocked = await deviceIsUnlocked()
        if unlocked && !alertTitle.isEmpty {
          alertConfig = AlertConfiguration(
            title: LocalizedStringResource(stringLiteral: alertTitle),
            body: LocalizedStringResource(
              stringLiteral: alertBody.isEmpty ? alertTitle : alertBody),
            sound: .default
          )
        }
        let content = ActivityContent(
          state: state,
          staleDate: Calendar.current.date(byAdding: .hour, value: 3, to: Date.now)
        )
        await activity.update(content, alertConfiguration: alertConfig)
      } else {
        await activity.update(using: state)
      }
    }
    return true
  }

  static func mirrorSnapshot(args: [String: Any]) {
    guard let shared = UserDefaults(suiteName: appGroupId) else { return }
    if let id = args["activityId"] as? String, !id.isEmpty {
      shared.set(id, forKey: runningIdKey)
    }
    if #available(iOS 16.1, *) {
      shared.set(uuid5(name: logicalActivityId).uuidString, forKey: keyPrefix)
    }
    if let prefix = args["keyPrefix"] as? String, !prefix.isEmpty {
      shared.set(prefix, forKey: keyPrefix)
    }
    if let p1 = args["logo1Path"] as? String, !p1.isEmpty {
      shared.set(p1, forKey: "dvcr_logo1_path")
    }
    if let p2 = args["logo2Path"] as? String, !p2.isEmpty {
      shared.set(p2, forKey: "dvcr_logo2_path")
    }
    shared.synchronize()
  }

  @available(iOS 16.1, *)
  static func hasActiveLiveActivity() async -> Bool {
    await resolvePluginActivity() != nil
  }

  private static let alwaysVisibleBannerTypes: Set<String> = [
    "live_start", "kickoff", "live_end",
  ]

  private static func allowsVisibleBannerWithLiveActivity(_ data: [String: String]) -> Bool {
    if data["endLive"] == "1" { return true }
    let type = data["type"] ?? ""
    return alwaysVisibleBannerTypes.contains(type)
  }

  static func shouldSuppressVisibleBanner(userInfo: [AnyHashable: Any]) async -> Bool {
    guard #available(iOS 16.1, *) else { return false }
    let data = parseFcmData(userInfo)
    // Début / fin de match : bannière même si Live Activity active.
    if data["notifyVisible"] == "1" {
      if allowsVisibleBannerWithLiveActivity(data) { return false }
      return await hasActiveLiveActivity()
    }
    // Syncs silencieux — ne jamais afficher en bannière
    if data["syncLiveActivity"] == "1" { return true }
    if data["type"] == "live_sync" { return true }
    return false
  }

  @discardableResult
  static func apply(userInfo: [AnyHashable: Any]) -> Bool {
    guard #available(iOS 16.1, *) else { return false }
    let data = parseFcmData(userInfo)
    if data["endLive"] == "1" || data["type"] == "live_end" {
      let semaphore = DispatchSemaphore(value: 0)
      var ended = false
      Task {
        ended = await endAllLiveActivities()
        semaphore.signal()
      }
      _ = semaphore.wait(timeout: .now() + 25)
      return ended
    }
    guard shouldSync(data) else { return false }

    let semaphore = DispatchSemaphore(value: 0)
    var laUpdated = false
    Task {
      laUpdated = await applyAsync(data: data)
      if !laUpdated {
        let laActive = await hasActiveLiveActivity()
        if !laActive {
          showLocalNotificationIfNeeded(data: data)
        }
      }
      semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 25)
    return laUpdated
  }

  @available(iOS 16.1, *)
  private static func endAllLiveActivities() async -> Bool {
    let pluginActivities = await MainActor.run {
      Activity<LiveActivitiesAppAttributes>.activities
    }
    for activity in pluginActivities {
      await activity.end(dismissalPolicy: .immediate)
    }
    if let shared = UserDefaults(suiteName: appGroupId) {
      shared.removeObject(forKey: runningIdKey)
      shared.removeObject(forKey: keyPrefix)
      shared.removeObject(forKey: "dvcr_logo1_path")
      shared.removeObject(forKey: "dvcr_logo2_path")
      shared.synchronize()
    }
    return true
  }

  @available(iOS 16.1, *)
  private static func applyAsync(data: [String: String]) async -> Bool {
    guard let shared = UserDefaults(suiteName: appGroupId) else { return false }
    let payload = buildPayload(data: data, shared: shared)

    let activities = await MainActor.run {
      Activity<LiveActivitiesAppAttributes>.activities.filter { isUsableState($0.activityState) }
    }

    if !activities.isEmpty {
      for activity in activities {
        writePayload(payload, prefix: activity.attributes.id, shared: shared)
        shared.set(activity.id, forKey: runningIdKey)
        await updateActivity(activity, data: data, payload: payload)
      }
      return true
    }

    if let prefix = storedKeyPrefix(shared) {
      writePayload(payload, prefix: prefix, shared: shared)
    }

    return false
  }

  @available(iOS 16.1, *)
  private static func writePayload(
    _ payload: [String: Any],
    prefix: UUID,
    shared: UserDefaults
  ) {
    for (key, value) in payload {
      shared.set(value, forKey: "\(prefix)_\(key)")
    }
    shared.set(
      Int(Date().timeIntervalSince1970 * 1000),
      forKey: "\(prefix)_contentTick"
    )
    shared.set(prefix.uuidString, forKey: keyPrefix)
    shared.synchronize()
  }

  @available(iOS 16.1, *)
  private static func updateActivity(
    _ activity: Activity<LiveActivitiesAppAttributes>,
    data: [String: String],
    payload: [String: Any]
  ) async {
    // activity.content is iOS 16.2+; keep a nil previous on 16.1.
    let previous: LiveActivitiesAppAttributes.ContentState?
    if #available(iOS 16.2, *) {
      previous = activity.content.state
    } else {
      previous = nil
    }
    let state = contentState(
      from: payload,
      tick: Int(Date().timeIntervalSince1970 * 1000),
      previous: previous
    )
    let eventType = data["type"] ?? ""
    let isEvent = !eventType.isEmpty && eventType != "live_sync" && eventType != "live_end"
    let alertTitle = (data["alertTitle"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let shortBody = (data["alertShortBody"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

    if #available(iOS 16.2, *) {
      var alertConfig: AlertConfiguration?
      let unlocked = await deviceIsUnlocked()
      let locked = !unlocked
      if unlocked && isEvent && !alertTitle.isEmpty {
        let body = shortBody.isEmpty
          ? (data["alertBody"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
          : shortBody
        alertConfig = AlertConfiguration(
          title: LocalizedStringResource(stringLiteral: alertTitle),
          body: LocalizedStringResource(stringLiteral: body.isEmpty ? alertTitle : body),
          sound: .default
        )
      }
      let content = ActivityContent(
        state: state,
        staleDate: Calendar.current.date(byAdding: .hour, value: 3, to: Date.now)
      )
      // Toujours pousser la mise à jour widget (écran verrouillé) ; alerte DI seulement déverrouillé.
      await activity.update(content, alertConfiguration: locked ? nil : alertConfig)
    } else {
      await activity.update(using: state)
    }
  }

  /// Construit un ContentState riche (requis pour push ActivityKit + re-render local).
  /// Les clés absentes du payload gardent la valeur précédente (refresh chrono partiel).
  @available(iOS 16.1, *)
  private static func contentState(
    from data: [String: Any],
    tick: Int,
    previous: LiveActivitiesAppAttributes.ContentState? = nil
  ) -> LiveActivitiesAppAttributes.ContentState {
    func has(_ key: String) -> Bool {
      guard let v = data[key] else { return false }
      return !(v is NSNull)
    }
    func str(_ key: String) -> String {
      if let s = data[key] as? String { return s }
      if let n = data[key] as? NSNumber { return n.stringValue }
      return ""
    }
    func int(_ key: String) -> Int {
      if let n = data[key] as? Int { return n }
      if let n = data[key] as? NSNumber { return n.intValue }
      return Int(str(key)) ?? 0
    }
    func bool(_ key: String) -> Bool {
      if let b = data[key] as? Bool { return b }
      if let n = data[key] as? NSNumber { return n.intValue != 0 }
      let s = str(key).lowercased()
      if s == "0" || s == "false" || s == "no" || s == "away" { return false }
      return s == "1" || s == "true" || s == "yes" || s == "home"
    }
    let lastEvent = has("lastEvent") ? str("lastEvent") : (previous?.lastEvent ?? "")
    let eventLine: String
    if has("lastEventLine") || has("lastGoalLine") {
      eventLine = str("lastEventLine").isEmpty ? str("lastGoalLine") : str("lastEventLine")
    } else {
      eventLine = previous?.lastEventLine ?? ""
    }
    let minute: String
    if has("matchMinute") || has("teamAState") {
      minute = str("matchMinute").isEmpty ? str("teamAState") : str("matchMinute")
    } else {
      minute = previous?.matchMinute ?? ""
    }
    return LiveActivitiesAppAttributes.ContentState(
      appGroupId: appGroupId,
      teamAName: has("teamAName") ? str("teamAName") : (previous?.teamAName ?? ""),
      teamBName: has("teamBName") ? str("teamBName") : (previous?.teamBName ?? ""),
      teamAScore: has("teamAScore") ? int("teamAScore") : (previous?.teamAScore ?? 0),
      teamBScore: has("teamBScore") ? int("teamBScore") : (previous?.teamBScore ?? 0),
      matchMinute: minute,
      lastEventLine: eventLine,
      lastEventIsHome: has("lastEventIsHome")
        ? bool("lastEventIsHome")
        : (previous?.lastEventIsHome ?? true),
      contentTick: tick > 0 ? tick : (has("contentTick") ? int("contentTick") : (previous?.contentTick ?? 0)),
      chronoRunning: has("chronoRunning") ? bool("chronoRunning") : (previous?.chronoRunning ?? false),
      chronoBaseSeconds: has("chronoBaseSeconds")
        ? int("chronoBaseSeconds")
        : (previous?.chronoBaseSeconds ?? 0),
      chronoStartedAtMs: has("chronoStartedAtMs")
        ? int("chronoStartedAtMs")
        : (previous?.chronoStartedAtMs ?? 0),
      liveMinute: has("liveMinute") ? int("liveMinute") : (previous?.liveMinute ?? 0),
      isHalftime: (has("isHalftime") ? bool("isHalftime") : (previous?.isHalftime ?? false))
        || lastEvent == "halftime",
      isExtraHalftime: (has("isExtraHalftime") ? bool("isExtraHalftime") : (previous?.isExtraHalftime ?? false))
        || lastEvent == "extra_halftime",
      isFulltime: (has("isFulltime") ? bool("isFulltime") : (previous?.isFulltime ?? false))
        || lastEvent == "fulltime",
      isExtraFulltime: (has("isExtraFulltime") ? bool("isExtraFulltime") : (previous?.isExtraFulltime ?? false))
        || lastEvent == "extra_fulltime",
      isExtraTimePlaying: (has("isExtraTimePlaying")
        ? bool("isExtraTimePlaying")
        : (previous?.isExtraTimePlaying ?? false))
        || lastEvent == "extra_time",
      lastEvent: lastEvent
    )
  }

  @MainActor
  private static func deviceIsUnlocked() -> Bool {
    UIApplication.shared.isProtectedDataAvailable
  }

  private static let notifiableTypes: Set<String> = [
    "goal", "yellow", "yellow_card", "red", "red_card",
    "substitution", "halftime", "fulltime", "extra_fulltime",
  ]

  private static func showLocalNotificationIfNeeded(data: [String: String]) {
    let eventType = data["type"] ?? ""
    guard notifiableTypes.contains(eventType) else { return }

    let title = (data["alertTitle"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if title.isEmpty { return }

    let matchLine = (data["alertTitle"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let shortBody = (data["alertShortBody"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let fullBody = (data["alertBody"] ?? data["lastEventLine"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let detail = shortBody.isEmpty ? fullBody : shortBody

    let content = UNMutableNotificationContent()
    content.title = matchLine.isEmpty ? title : matchLine
    content.body = detail.isEmpty ? title : detail
    content.sound = .default
    content.userInfo = data.reduce(into: [AnyHashable: Any]()) { $0[$1.key] = $1.value }

    let request = UNNotificationRequest(
      identifier: "dvcr-live-\(eventType)-\(Date().timeIntervalSince1970)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  @available(iOS 16.1, *)
  private static func resolvePluginActivity() async -> Activity<LiveActivitiesAppAttributes>? {
    let all = await MainActor.run { Activity<LiveActivitiesAppAttributes>.activities }
    return pickPluginActivity(all)
  }

  @available(iOS 16.1, *)
  private static func isUsableState(_ state: ActivityState) -> Bool {
    if #available(iOS 16.2, *) {
      return state == .active || state == .stale
    }
    return state == .active
  }

  @available(iOS 16.1, *)
  private static func pickPluginActivity(
    _ all: [Activity<LiveActivitiesAppAttributes>]
  ) -> Activity<LiveActivitiesAppAttributes>? {
    let live = all.filter { isUsableState($0.activityState) }
    if live.isEmpty { return nil }

    let storedId = UserDefaults(suiteName: appGroupId)?.string(forKey: runningIdKey) ?? ""
    if !storedId.isEmpty {
      for item in live where item.id == storedId {
        return item
      }
    }

    let targetUuid = uuid5(name: logicalActivityId)
    for item in live where item.attributes.id == targetUuid {
      return item
    }
    return live[0]
  }

  private static func storedKeyPrefix(_ shared: UserDefaults) -> UUID? {
    guard let raw = shared.string(forKey: keyPrefix) else { return nil }
    return UUID(uuidString: raw)
  }

  private static func parseFcmData(_ userInfo: [AnyHashable: Any]) -> [String: String] {
    var out: [String: String] = [:]
    for (rawKey, rawValue) in userInfo {
      guard let key = rawKey as? String else { continue }
      if key == "aps" || key.hasPrefix("google.") || key.hasPrefix("gcm.") || key == "from" {
        continue
      }
      out[key] = stringValue(rawValue)
    }
    return out
  }

  private static func stringValue(_ value: Any) -> String {
    if let s = value as? String { return s }
    if let n = value as? NSNumber { return n.stringValue }
    return "\(value)"
  }

  private static func shouldSync(_ data: [String: String]) -> Bool {
    if data["syncLiveActivity"] == "1" { return true }
    let type = data["type"] ?? ""
    return syncTypes.contains(type)
  }

  private static func liveActivityEnabled() -> Bool {
    let std = UserDefaults.standard
    if std.object(forKey: "flutter.notif_live_sticky_score") != nil {
      return std.bool(forKey: "flutter.notif_live_sticky_score")
    }
    if std.object(forKey: "flutter.notif_live") != nil {
      return std.bool(forKey: "flutter.notif_live")
    }
    return true
  }

  private static func buildPayload(data: [String: String], shared: UserDefaults) -> [String: Any] {
    let team1 = shortTeam(data["team1"] ?? "")
    let team2 = shortTeam(data["team2"] ?? "")
    let scoreHome = intValue(data["scoreHome"])
    let scoreAway = intValue(data["scoreAway"])
    let lastEvent = data["lastEvent"] ?? ""
    let minuteLabel = formattedMinute(data: data, lastEvent: lastEvent)
    let lastLine = compactLine(data["lastEventLine"] ?? "")
    let lastEventIsHome = parseIsHomeFlag(data["lastEventIsHome"])

    let chronoRunning = data["chronoRunning"] == "1"
    let chronoBase = intValue(data["chronoBaseSeconds"])
    let chronoStarted = intValue(data["chronoStartedAtMs"])
    let liveMinute = intValue(data["minute"])

    var payload: [String: Any] = [
      "matchName": brandName,
      "teamAName": team1,
      "teamBName": team2,
      "teamAState": minuteLabel,
      "teamBState": "LIVE",
      "teamAScore": scoreHome,
      "teamBScore": scoreAway,
      "matchMinute": minuteLabel,
      "lastGoalLine": lastLine,
      "lastEventLine": lastLine,
      "lastEventIsHome": lastEventIsHome,
      "liveMinute": liveMinute,
      "chronoRunning": chronoRunning,
      "chronoBaseSeconds": chronoBase,
      "chronoStartedAtMs": chronoStarted,
      "isHalftime": lastEvent == "halftime",
      "isExtraHalftime": lastEvent == "extra_halftime",
      "isFulltime": lastEvent == "fulltime",
      "isExtraFulltime": lastEvent == "extra_fulltime",
      "isExtraTimePlaying": lastEvent == "extra_time",
      "lastEvent": lastEvent,
    ]

    let logo1 = shared.string(forKey: "dvcr_logo1_path") ?? ""
    let logo2 = shared.string(forKey: "dvcr_logo2_path") ?? ""
    if !logo1.isEmpty { payload["teamALogo"] = logo1 }
    if !logo2.isEmpty { payload["teamBLogo"] = logo2 }

    return payload
  }

  /// "1"/"true"/"home" → domicile (gauche) ; "0"/"false"/"away" → extérieur (droite).
  private static func parseIsHomeFlag(_ raw: String?) -> Bool {
    let t = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if t.isEmpty { return true }
    if t == "0" || t == "false" || t == "no" || t == "away" { return false }
    return true
  }

  private static func formattedMinute(data: [String: String], lastEvent: String) -> String {
    if lastEvent == "fulltime" || lastEvent == "extra_fulltime" { return "Fin" }
    if lastEvent == "halftime" || lastEvent == "extra_halftime" { return "Mi-temps" }
    if lastEvent == "extra_time" { return "Prol." }
    let minute = intValue(data["minute"])
    if minute > 0 { return "\(minute)'" }
    if data["chronoRunning"] == "1" { return "0'" }
    return "LIVE"
  }

  private static func shortTeam(_ raw: String) -> String {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.isEmpty { return "—" }
    if t.count <= 16 { return t }
    return String(t.prefix(14)) + "…"
  }

  private static func compactLine(_ raw: String) -> String {
    let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if line.isEmpty { return "" }
    if line.count <= 34 { return line }
    return String(line.prefix(32)) + "…"
  }

  private static func intValue(_ raw: String?) -> Int {
    Int(raw ?? "") ?? 0
  }

  private static func uuid5(
    namespace: UUID = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!,
    name: String
  ) -> UUID {
    var namespaceBytes = withUnsafeBytes(of: namespace.uuid) { Data($0) }
    namespaceBytes.append(Data(name.utf8))
    let hash = Insecure.SHA1.hash(data: namespaceBytes)
    var bytes = [UInt8](hash.prefix(16))
    bytes[6] = (bytes[6] & 0x0F) | 0x50
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    let uuid = uuid_t(
      bytes[0], bytes[1], bytes[2], bytes[3],
      bytes[4], bytes[5], bytes[6], bytes[7],
      bytes[8], bytes[9], bytes[10], bytes[11],
      bytes[12], bytes[13], bytes[14], bytes[15]
    )
    return UUID(uuid: uuid)
  }
}
