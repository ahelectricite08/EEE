/// Modèles de texte pour les partages — surchargés depuis Firestore
/// `app_config/share_text_templates` (voir [ShareTemplateSettings]).
class ShareTemplateSettings {
  const ShareTemplateSettings({
    required this.signOffBody,
    required this.siteUrl,
    required this.articleDefault,
    required this.articleByCategory,
    required this.videoDefault,
    required this.videoByCategory,
    required this.matchFinishedScored,
    required this.matchFinishedNoScore,
    required this.matchLive,
    required this.matchUpcoming,
    required this.replayStrip,
    required this.tournamentEmpty,
    required this.tournamentRanked,
    required this.cssaFavoriteRanking,
    required this.prediction,
  });

  /// Texte complet injecté pour `{{signOff}}` (y compris sauts de ligne).
  /// Vide = signature DVCR par défaut avec [siteUrl] ou https://www.dvcr.fr
  final String signOffBody;
  final String siteUrl;

  final String articleDefault;
  final Map<String, String> articleByCategory;

  final String videoDefault;
  final Map<String, String> videoByCategory;

  final String matchFinishedScored;
  final String matchFinishedNoScore;
  final String matchLive;
  final String matchUpcoming;

  final String replayStrip;
  final String tournamentEmpty;
  final String tournamentRanked;
  final String cssaFavoriteRanking;
  final String prediction;

  static const ShareTemplateSettings defaults = ShareTemplateSettings(
    signOffBody: '',
    siteUrl: '',
    articleDefault: '',
    articleByCategory: {},
    videoDefault: '',
    videoByCategory: {},
    matchFinishedScored: '',
    matchFinishedNoScore: '',
    matchLive: '',
    matchUpcoming: '',
    replayStrip: '',
    tournamentEmpty: '',
    tournamentRanked: '',
    cssaFavoriteRanking: '',
    prediction: '',
  );

  static String builtInSignOff(String site) {
    final s = site.trim().isEmpty ? 'https://www.dvcr.fr' : site.trim();
    return '\n\n— —\n'
        'Avec la team DVCR : 100% CSSA, 100% passion foot.\n'
        'Rejoins-nous sur l’app ou sur $s.';
  }

  String resolveSignOff() {
    final custom = signOffBody.trim();
    if (custom.isNotEmpty) return custom;
    final site = siteUrl.trim().isNotEmpty ? siteUrl.trim() : '';
    return builtInSignOff(site);
  }

  static String _normKey(String k) => k.trim().toUpperCase();

  String resolveArticleTemplate(String category) {
    final nk = _normKey(category);
    for (final e in articleByCategory.entries) {
      if (_normKey(e.key) == nk && e.value.trim().isNotEmpty) {
        return e.value.trim();
      }
    }
    if (articleDefault.trim().isNotEmpty) return articleDefault.trim();
    return kDefaultArticleTemplate;
  }

  String resolveVideoTemplate(String category) {
    final nk = _normKey(category);
    for (final e in videoByCategory.entries) {
      if (_normKey(e.key) == nk && e.value.trim().isNotEmpty) {
        return e.value.trim();
      }
    }
    if (videoDefault.trim().isNotEmpty) return videoDefault.trim();
    return kDefaultVideoTemplate;
  }

  String matchFinishedScoredTpl() =>
      matchFinishedScored.trim().isNotEmpty
          ? matchFinishedScored.trim()
          : kDefaultMatchFinishedScored;

  String matchFinishedNoScoreTpl() =>
      matchFinishedNoScore.trim().isNotEmpty
          ? matchFinishedNoScore.trim()
          : kDefaultMatchFinishedNoScore;

  String matchLiveTpl() =>
      matchLive.trim().isNotEmpty ? matchLive.trim() : kDefaultMatchLive;

  String matchUpcomingTpl() =>
      matchUpcoming.trim().isNotEmpty
          ? matchUpcoming.trim()
          : kDefaultMatchUpcoming;

  String replayStripTpl() =>
      replayStrip.trim().isNotEmpty ? replayStrip.trim() : kDefaultReplayStrip;

  String tournamentEmptyTpl() =>
      tournamentEmpty.trim().isNotEmpty
          ? tournamentEmpty.trim()
          : kDefaultTournamentEmpty;

  String tournamentRankedTpl() =>
      tournamentRanked.trim().isNotEmpty
          ? tournamentRanked.trim()
          : kDefaultTournamentRanked;

  String cssaFavoriteTpl() =>
      cssaFavoriteRanking.trim().isNotEmpty
          ? cssaFavoriteRanking.trim()
          : kDefaultCssaFavorite;

  String predictionTpl() =>
      prediction.trim().isNotEmpty ? prediction.trim() : kDefaultPrediction;

  factory ShareTemplateSettings.fromMap(Map<String, dynamic>? data) {
    Map<String, String> readCat(dynamic v) {
      if (v is! Map) return {};
      return v.map(
        (k, val) => MapEntry(k.toString(), val?.toString() ?? ''),
      );
    }

    String s(String key) => (data?[key] ?? '').toString();

    return ShareTemplateSettings(
      signOffBody: s('signOffBody'),
      siteUrl: s('siteUrl'),
      articleDefault: s('articleDefault'),
      articleByCategory: readCat(data?['articleByCategory']),
      videoDefault: s('videoDefault'),
      videoByCategory: readCat(data?['videoByCategory']),
      matchFinishedScored: s('matchFinishedScored'),
      matchFinishedNoScore: s('matchFinishedNoScore'),
      matchLive: s('matchLive'),
      matchUpcoming: s('matchUpcoming'),
      replayStrip: s('replayStrip'),
      tournamentEmpty: s('tournamentEmpty'),
      tournamentRanked: s('tournamentRanked'),
      cssaFavoriteRanking: s('cssaFavoriteRanking'),
      prediction: s('prediction'),
    );
  }

  Map<String, dynamic> toMap() => {
        'signOffBody': signOffBody,
        'siteUrl': siteUrl,
        'articleDefault': articleDefault,
        'articleByCategory': articleByCategory,
        'videoDefault': videoDefault,
        'videoByCategory': videoByCategory,
        'matchFinishedScored': matchFinishedScored,
        'matchFinishedNoScore': matchFinishedNoScore,
        'matchLive': matchLive,
        'matchUpcoming': matchUpcoming,
        'replayStrip': replayStrip,
        'tournamentEmpty': tournamentEmpty,
        'tournamentRanked': tournamentRanked,
        'cssaFavoriteRanking': cssaFavoriteRanking,
        'prediction': prediction,
      };

  /// Remplace `{{cle}}` par la valeur correspondante (sensible à la casse des clés).
  static String interpolate(String template, Map<String, String> vars) {
    var out = template;
    vars.forEach((k, v) {
      out = out.replaceAll('{{$k}}', v);
    });
    return out;
  }
}

// ── Textes par défaut (alignés sur l’ancien ShareHelper) ─────────────────────

const String kDefaultArticleTemplate = r'{{emoji}} {{title}}'
    '\n{{category}} · {{date}}\n\n'
    '{{excerpt}}\n\n'
    'Une actu DVCR à partager avec les tiens — merci de faire vivre le club !{{signOff}}';

const String kDefaultVideoTemplate = r'{{emoji}} {{title}}'
    '\n{{meta}}\n\n'
    'Un moment DVCR TV à regarder entre amis — bon match & bon replay !{{signOff}}';

const String kDefaultMatchFinishedScored = r'{{header}}'
    '\n{{team1}} {{s1}} – {{s2}} {{team2}}'
    '\n{{when}}{{compLine}}\n\n'
    '{{outro}}{{signOff}}';

const String kDefaultMatchFinishedNoScore = r'⚽ Résultat DVCR'
    '\n{{team1}} vs {{team2}}'
    '\n{{when}}{{compLine}}\n\n'
    'On pense à vous depuis les tribunes DVCR.{{signOff}}';

const String kDefaultMatchLive = r'🔴 Ça joue maintenant !'
    '\n{{team1}} vs {{team2}}'
    '\n{{scoreLine}}{{when}}{{compLine}}\n\n'
    'Viens vibrer avec nous sur l’app DVCR (live, stats, ambiance).{{signOff}}';

const String kDefaultMatchUpcoming = r'⚽ Rendez-vous au stade (ou sur l’app !)'
    '\n{{team1}} vs {{team2}}'
    '\n{{when}}{{compLine}}\n\n'
    'Rendez-vous sur l’app DVCR pour suivre le match en famille.{{signOff}}';

const String kDefaultReplayStrip = r'{{emoji}} {{title}}'
    '\n{{duration}} · {{relativeDate}}\n\n'
    'Un extrait DVCR TV à partager avec ta team !{{signOff}}';

const String kDefaultTournamentEmpty = r'🏆 {{tournamentLabel}} — DVCR'
    '\nJe joue aux pronos avec la famille DVCR.\n\n'
    'Viens défier la tribu (dans la bonne humeur, promis) !{{signOff}}';

const String kDefaultTournamentRanked = r'🏆 {{tournamentLabel}} — DVCR'
    '\n{{rankLine}}{{who}}\n\n'
    'Merci à tous les pronostiqueurs : on se retrouve sur l’app pour la suite !{{signOff}}';

const String kDefaultCssaFavorite = r'⚽ Notre club, notre fierté — DVCR'
    '\n{{clubName}} est {{place}} avec {{pts}} pts.\n'
    '{{leagueLabel}} · saison {{season}} · après {{mj}} matchs : '
    '{{v}} V, {{n}} N, {{d}} D · buts {{bf}}-{{bc}} (diff. {{diffSign}}{{diff}}).\n\n'
    'Partage ce classement avec ceux qui encouragent depuis le salon ou la buvette !{{signOff}}';

const String kDefaultPrediction = r'🎯 Mon prono DVCR'
    '\n{{team1}} {{score1}} - {{score2}} {{team2}}'
    '\n{{dateLabel}}\n\n'
    'J’y crois — et toi ? Viens jouer le jeu avec la tribu DVCR.{{signOff}}';
