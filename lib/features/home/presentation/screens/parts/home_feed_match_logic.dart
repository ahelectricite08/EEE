part of '../home_screen.dart';

Stream<String?> _watchHomeStadiumHero(String teamName) =>
    HomeStadiumDatasource().watchStadiumImageUrl(teamName);

Color _catColor(String cat) {
  switch (cat.toUpperCase()) {
    case 'RÉSULTATS':
      return const Color(0xFF4CAF50);
    case 'AVANT-MATCH':
      return const Color(0xFFFF9800);
    case 'CHRONIQUES SEDANAISES':
      return const Color(0xFF2196F3);
    case 'ANALYSE':
      return const Color(0xFF9C27B0);
    case 'COULISSES':
      return const Color(0xFFFF9800);
    case 'CLUB':
      return _kRed;
    case ArticleModel.kUncategorizedToutOnly:
      return _kGrey;
    default:
      return _kRed;
  }
}

bool _isSedanMatch(MatchModel match) {
  final team1 = match.team1.toUpperCase();
  final team2 = match.team2.toUpperCase();
  return team1.contains('SEDAN') ||
      team1.contains('CSSA') ||
      team2.contains('SEDAN') ||
      team2.contains('CSSA');
}

/// Victoire / défaite / nul du point de vue du CSSA (team1 = domicile, team2 = extérieur).
String _cssaResultLabel(MatchModel match) {
  if (match.score1 == null || match.score2 == null) return 'EN ATTENTE';
  final s1 = match.score1!;
  final s2 = match.score2!;
  final t1 = match.team1.toUpperCase();
  final t2 = match.team2.toUpperCase();
  final sedan1 = t1.contains('SEDAN') || t1.contains('CSSA');
  final sedan2 = t2.contains('SEDAN') || t2.contains('CSSA');
  if (!sedan1 && !sedan2) {
    if (s1 == s2) return 'MATCH NUL';
    return s1 > s2 ? 'VICTOIRE' : 'DÉFAITE';
  }
  final cssaGoals = sedan1 ? s1 : s2;
  final oppGoals = sedan1 ? s2 : s1;
  if (cssaGoals == oppGoals) return 'MATCH NUL';
  return cssaGoals > oppGoals ? 'VICTOIRE' : 'DÉFAITE';
}

/// Couleur du pastille résultat (vert / or nul / rouge / gris).
Color _cssaResultAccent(MatchModel match) {
  switch (_cssaResultLabel(match)) {
    case 'VICTOIRE':
      return _kGreen;
    case 'DÉFAITE':
      return _kRed;
    case 'MATCH NUL':
      return _kGold;
    default:
      return _kGrey;
  }
}

bool _looseTeamName(String a, String b) {
  final at = a.trim().toUpperCase();
  final bt = b.trim().toUpperCase();
  if (at.isEmpty || bt.isEmpty) return false;
  final aw = at
      .split(RegExp(r'\s+'))
      .firstWhere((s) => s.isNotEmpty, orElse: () => at);
  final bw = bt
      .split(RegExp(r'\s+'))
      .firstWhere((s) => s.isNotEmpty, orElse: () => bt);
  return at.contains(bw) || bt.contains(aw);
}

bool _hubCoversMatch(LiveHubState hub, MatchModel m) {
  final id = hub.liveMatchId.trim();
  if (id.isNotEmpty) return id == m.id;
  final t1 = hub.matchTeam1.toUpperCase();
  final t2 = hub.matchTeam2.toUpperCase();
  if (t1.isEmpty && t2.isEmpty) return false;
  final m1 = m.team1.toUpperCase();
  final m2 = m.team2.toUpperCase();
  return (_looseTeamName(t1, m1) && _looseTeamName(t2, m2)) ||
      (_looseTeamName(t1, m2) && _looseTeamName(t2, m1));
}

MatchModel? _findMatchForLiveHub(HomeMatchCatalogAdapter ctrl, LiveHubState hub) {
  if (!hub.isMatchLive) return null;
  final id = hub.liveMatchId.trim();
  if (id.isNotEmpty) {
    for (final m in [...ctrl.upcoming, ...ctrl.results]) {
      if (m.id == id) return m;
    }
    // Ne pas retomber sur un matching flou : un autre match (ex. futur) pourrait
    // absorber le flux live si le `matchId` du hub ne correspond plus au calendrier.
    return null;
  }
  for (final m in [...ctrl.upcoming, ...ctrl.results]) {
    if (_hubCoversMatch(hub, m)) return m;
  }
  return null;
}

const Duration _homeMatchHoldAfterKickoff = Duration(hours: 2);

/// 1) Live hub / match en direct. 2) Sinon prochain Sedan à venir. Sinon rien (pas de mock).
MatchModel? _pickHomeFeaturedMatch(HomeMatchCatalogAdapter ctrl, LiveHubState hub) {
  final liveM = _findMatchForLiveHub(ctrl, hub);
  if (liveM != null) {
    return liveM;
  }

  if (hub.isMatchLive &&
      (hub.matchTeam1.trim().isNotEmpty || hub.matchTeam2.trim().isNotEmpty)) {
    return MatchModel(
      id: hub.liveMatchId.trim().isNotEmpty ? hub.liveMatchId.trim() : 'live_hub',
      team1: hub.matchTeam1,
      team2: hub.matchTeam2,
      logo1: hub.matchLogo1,
      logo2: hub.matchLogo2,
      date: DateTime.now(),
      competition: '',
      status: MatchStatus.live,
    );
  }

  final now = DateTime.now();
  final sedanUpcoming = ctrl.upcoming
      .where(_isSedanMatch)
      .where(
        (m) =>
            m.status == MatchStatus.upcoming && m.date.isAfter(now),
      )
      .toList();
  if (sedanUpcoming.isNotEmpty) {
    return sedanUpcoming.first;
  }

  return null;
}

bool _showHomeFeaturedMatchSection(
  HomeMatchCatalogAdapter ctrl,
  LiveHubState hub,
  SeasonLifecycleConfig life,
) {
  if (life.betweenSeasons) return true;
  return _pickHomeFeaturedMatch(ctrl, hub) != null;
}

/// IDs `m1`, `m2`… (carte d’illustration) : pas de doc `predictions` alignée avec le hub prono.
bool _isHomePronoPlaceholderMatchId(String id) =>
    RegExp(r'^m\d+$').hasMatch(id.trim());

/// Pastille « STATS EN DIRECT » sur la carte accueil : uniquement si le toggle admin est ON.
bool _homeShowLiveStatsOnCard(MatchModel match, LiveHubState hub) =>
    match.status == MatchStatus.live &&
    hub.isMatchLive &&
    _hubCoversMatch(hub, match) &&
    hub.liveStatsToggleOn;

MatchModel _buildHomeDisplayMatch(MatchModel match, LiveHubState hub) {
  // Tant que `live/current` existe pour ce match, carte **toujours** en mode direct
  // (même si `matches/{id}` est déjà repassé en `finished` — sinon écran TERMINÉ / footer nul).
  if (hub.isMatchLive && _hubCoversMatch(hub, match)) {
    return MatchModel(
      id: match.id,
      team1: hub.matchTeam1.isNotEmpty ? hub.matchTeam1 : match.team1,
      team2: hub.matchTeam2.isNotEmpty ? hub.matchTeam2 : match.team2,
      logo1: hub.matchLogo1.isNotEmpty ? hub.matchLogo1 : match.logo1,
      logo2: hub.matchLogo2.isNotEmpty ? hub.matchLogo2 : match.logo2,
      score1: match.score1,
      score2: match.score2,
      date: match.date,
      competition: match.competition,
      status: MatchStatus.live,
      replayVideoId: match.replayVideoId,
      stats: match.stats,
      rank1: match.rank1,
      rank2: match.rank2,
      form1: match.form1,
      form2: match.form2,
      wdl1: match.wdl1,
      wdl2: match.wdl2,
      stadiumImageUrl: match.stadiumImageUrl,
      earlyPublish: match.earlyPublish,
      fffSeason: match.fffSeason,
    );
  }

  return match;
}

String _homeFeaturedSectionTitle(MatchModel match, LiveHubState hub) {
  if (hub.isMatchLive && _hubCoversMatch(hub, match)) {
    return 'Match en direct';
  }
  return 'Prochain match';
}

IconData _homeFeaturedSectionIcon(MatchModel match, LiveHubState hub) {
  if (hub.isMatchLive && _hubCoversMatch(hub, match)) {
    return Icons.live_tv_rounded;
  }
  return Icons.event_available_rounded;
}
