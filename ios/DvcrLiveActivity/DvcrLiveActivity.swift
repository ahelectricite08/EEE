import ActivityKit
import SwiftUI
import WidgetKit

@main
struct DvcrLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            DvcrMatchLiveWidget()
        }
    }
}

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState
    public struct ContentState: Codable, Hashable {}
    var id = UUID()
}

let sharedDefault = UserDefaults(suiteName: "group.fr.dvcr.app.liveactivities")!

@available(iOSApplicationExtension 16.1, *)
private struct DvcrLiveActivityData {
    let teamA: String
    let teamB: String
    let scoreA: Int
    let scoreB: Int
    let status: String
    let matchName: String
    let lastEvent: String
    let logoAPath: String?
    let logoBPath: String?

    init(context: ActivityViewContext<LiveActivitiesAppAttributes>) {
        let key = context.attributes.prefixedKey
        teamA = sharedDefault.string(forKey: key("teamAName")) ?? "—"
        teamB = sharedDefault.string(forKey: key("teamBName")) ?? "—"
        scoreA = sharedDefault.integer(forKey: key("teamAScore"))
        scoreB = sharedDefault.integer(forKey: key("teamBScore"))
        status = sharedDefault.string(forKey: key("teamAState")) ?? "LIVE"
        matchName = sharedDefault.string(forKey: key("matchName")) ?? "Drapeau Vert Carton Rouge"
        let rawEvent = sharedDefault.string(forKey: key("lastEventLine"))
            ?? sharedDefault.string(forKey: key("lastGoalLine"))
            ?? ""
        lastEvent = dvcrCompactEventLine(rawEvent)
        let pathA = sharedDefault.string(forKey: key("teamALogo")) ?? ""
        let pathB = sharedDefault.string(forKey: key("teamBLogo")) ?? ""
        logoAPath = pathA.isEmpty ? nil : pathA
        logoBPath = pathB.isEmpty ? nil : pathB
    }
}

@available(iOSApplicationExtension 16.1, *)
private func dvcrCompactEventLine(_ raw: String) -> String {
    let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if line.isEmpty { return "" }
    if line.count <= 34 { return line }
    return String(line.prefix(32)) + "…"
}

@available(iOSApplicationExtension 16.1, *)
private func dvcrTeamInitials(_ name: String) -> String {
    let parts = name
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(whereSeparator: { $0.isWhitespace })
    if parts.count >= 2 {
        return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
    }
    if name.isEmpty { return "—" }
    return String(name.prefix(2)).uppercased()
}

@available(iOSApplicationExtension 16.1, *)
private struct DvcrTeamMonogram: View {
    let name: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))
            Circle()
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
            Text(dvcrTeamInitials(name))
                .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct DvcrTeamBadge: View {
    let logoPath: String?
    let name: String
    let size: CGFloat
    let showName: Bool

    var body: some View {
        VStack(spacing: 4) {
            if let path = logoPath, let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
            } else {
                DvcrTeamMonogram(name: name, size: size)
            }
            if showName {
                Text(name)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: size + 12)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct DvcrScoreCenter: View {
    let scoreA: Int
    let scoreB: Int
    let status: String
    let lastEvent: String
    let gold: Color

    private var hasEvent: Bool { !lastEvent.isEmpty }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(scoreA) : \(scoreB)")
                .font(.system(size: hasEvent ? 24 : 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if hasEvent {
                Text(lastEvent)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else {
                Text("DIRECT")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(gold.opacity(0.65))
                    .tracking(0.5)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct DvcrLiveLockScreenView: View {
    let data: DvcrLiveActivityData

    private let bgTop = Color(red: 0.05, green: 0.35, blue: 0.26)
    private let bgBottom = Color(red: 0.02, green: 0.16, blue: 0.12)
    private let gold = Color(red: 0.96, green: 0.84, blue: 0.43)

    private var hasEventLine: Bool { !data.lastEvent.isEmpty }
    private var badgeSize: CGFloat { hasEventLine ? 40 : 44 }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [bgTop, bgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 7) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(red: 0.91, green: 0.36, blue: 0.42))
                        .frame(width: 6, height: 6)
                    Text(data.matchName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 2)
                    Text(data.status)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(gold)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(gold.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }

                HStack(alignment: .center, spacing: 6) {
                    DvcrTeamBadge(
                        logoPath: data.logoAPath,
                        name: data.teamA,
                        size: badgeSize,
                        showName: !hasEventLine
                    )
                    DvcrScoreCenter(
                        scoreA: data.scoreA,
                        scoreB: data.scoreB,
                        status: data.status,
                        lastEvent: data.lastEvent,
                        gold: gold
                    )
                    .layoutPriority(1)
                    DvcrTeamBadge(
                        logoPath: data.logoBPath,
                        name: data.teamB,
                        size: badgeSize,
                        showName: !hasEventLine
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .activityBackgroundTint(bgTop)
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct DvcrIslandLogo: View {
    let path: String?
    let name: String

    var body: some View {
        if let path, let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .clipShape(Circle())
        } else {
            DvcrTeamMonogram(name: name, size: 20)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct DvcrMatchLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            DvcrLiveLockScreenView(data: DvcrLiveActivityData(context: context))
        } dynamicIsland: { context in
            let data = DvcrLiveActivityData(context: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DvcrTeamBadge(
                        logoPath: data.logoAPath,
                        name: data.teamA,
                        size: 32,
                        showName: false
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DvcrTeamBadge(
                        logoPath: data.logoBPath,
                        name: data.teamB,
                        size: 32,
                        showName: false
                    )
                }
                DynamicIslandExpandedRegion(.center) {
                    DvcrScoreCenter(
                        scoreA: data.scoreA,
                        scoreB: data.scoreB,
                        status: data.status,
                        lastEvent: data.lastEvent,
                        gold: Color(red: 0.96, green: 0.84, blue: 0.43)
                    )
                }
            } compactLeading: {
                DvcrIslandLogo(path: data.logoAPath, name: data.teamA)
            } compactTrailing: {
                Text("\(data.scoreA):\(data.scoreB)")
                    .font(.caption2.bold())
                    .lineLimit(1)
            } minimal: {
                Text("⚽")
            }
        }
    }
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        "\(id)_\(key)"
    }
}
