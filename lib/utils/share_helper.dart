import 'package:intl/intl.dart';

import '../models/article_model.dart';
import '../models/match_model.dart';
import '../models/video_model.dart';
import '../services/share_templates_cache.dart';
import 'share_template_settings.dart';

/// Textes de partage — modèles surchargés via Firestore `app_config/share_text_templates`
/// (admin → Paramètres → Textes de partage). Placeholders : `{{title}}`, `{{signOff}}`, etc.
class ShareHelper {
  ShareHelper._();

  static String articleText(ArticleModel article) {
    final cfg = ShareTemplatesCache.settings;
    final preview = article.content
        .replaceAll(RegExp(r'\[PHOTO:.*?\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final excerpt = preview.length > 200
        ? '${preview.substring(0, 200).trimRight()}…'
        : preview;
    final signOff = cfg.resolveSignOff();
    final tpl = cfg.resolveArticleTemplate(article.categoryForShare);
    return ShareTemplateSettings.interpolate(tpl, {
      'emoji': '📰',
      'title': article.title,
      'category': article.categoryForShare,
      'date': _formatDate(article.date),
      'excerpt': excerpt,
      'signOff': signOff,
    });
  }

  static String matchText(MatchModel match) {
    final cfg = ShareTemplatesCache.settings;
    final when = DateFormat(
      "EEEE d MMMM yyyy 'à' HH'h'mm",
      'fr_FR',
    ).format(match.date);
    final comp = match.competition.trim();
    final compLine = comp.isEmpty ? '' : ' · $comp';
    final signOff = cfg.resolveSignOff();

    switch (match.status) {
      case MatchStatus.finished:
        final s1 = match.score1;
        final s2 = match.score2;
        if (s1 != null && s2 != null) {
          final t1 = match.team1.toLowerCase();
          final t2 = match.team2.toLowerCase();
          final isSedanMatch = t1.contains('sedan') ||
              t2.contains('sedan') ||
              t1.contains('cssa') ||
              t2.contains('cssa');
          final outro = isSedanMatch
              ? 'Score final du CSSA. Allez Sedan !'
              : 'Score final à partager avec la famille DVCR.';
          final tpl = cfg.matchFinishedScoredTpl();
          return ShareTemplateSettings.interpolate(tpl, {
            'header': '⚽ Score final',
            'team1': match.team1,
            'team2': match.team2,
            's1': '$s1',
            's2': '$s2',
            'when': when,
            'compLine': compLine,
            'outro': outro,
            'signOff': signOff,
          });
        }
        final tpl = cfg.matchFinishedNoScoreTpl();
        return ShareTemplateSettings.interpolate(tpl, {
          'team1': match.team1,
          'team2': match.team2,
          'when': when,
          'compLine': compLine,
          'signOff': signOff,
        });
      case MatchStatus.live:
        final s1 = match.score1;
        final s2 = match.score2;
        final scoreLine = (s1 != null && s2 != null)
            ? 'Score en direct : $s1 – $s2\n'
            : '';
        final tpl = cfg.matchLiveTpl();
        return ShareTemplateSettings.interpolate(tpl, {
          'team1': match.team1,
          'team2': match.team2,
          'scoreLine': scoreLine,
          'when': when,
          'compLine': compLine,
          'signOff': signOff,
        });
      case MatchStatus.upcoming:
        final tpl = cfg.matchUpcomingTpl();
        return ShareTemplateSettings.interpolate(tpl, {
          'team1': match.team1,
          'team2': match.team2,
          'when': when,
          'compLine': compLine,
          'signOff': signOff,
        });
    }
  }

  static String videoText(VideoModel video) {
    final cfg = ShareTemplatesCache.settings;
    final dateLabel = _formatDate(video.date);
    final meta = <String>[
      if (video.category.trim().isNotEmpty) video.category.trim(),
      if (video.duration.trim().isNotEmpty) video.duration.trim(),
      dateLabel,
    ].join(' · ');
    final tpl = cfg.resolveVideoTemplate(video.category);
    return ShareTemplateSettings.interpolate(tpl, {
      'emoji': '🎬',
      'title': video.title,
      'meta': meta,
      'signOff': cfg.resolveSignOff(),
    });
  }

  /// Carte replay compacte (liste sans [VideoModel] complet).
  static String replayStripShareText({
    required String title,
    required String duration,
    required String relativeDate,
  }) {
    final cfg = ShareTemplatesCache.settings;
    final tpl = cfg.replayStripTpl();
    return ShareTemplateSettings.interpolate(tpl, {
      'emoji': '🎬',
      'title': title,
      'duration': duration,
      'relativeDate': relativeDate,
      'signOff': cfg.resolveSignOff(),
    });
  }

  static String tournamentRankingShareText({
    required String tournamentLabel,
    int? rank,
    required int points,
    required int exactScores,
    String? displayName,
  }) {
    final cfg = ShareTemplatesCache.settings;
    final signOff = cfg.resolveSignOff();
    if (rank == null && points == 0 && exactScores == 0) {
      return ShareTemplateSettings.interpolate(
        cfg.tournamentEmptyTpl(),
        {
          'tournamentLabel': tournamentLabel,
          'signOff': signOff,
        },
      );
    }
    final pseudo = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : null;
    final exactLine = exactScores > 0
        ? (exactScores == 1
            ? ' · 1 score exact'
            : ' · $exactScores scores exacts')
        : '';
    final rankLine = rank != null && rank >= 1
        ? (rank == 1
            ? 'Je suis en tête du classement avec $points pts$exactLine — fierté (modeste) de tribune !'
            : 'Je suis ${rank}e au classement avec $points pts$exactLine.')
        : 'Je suis au classement avec $points pts$exactLine.';
    final who = pseudo != null ? '\nPseudo : $pseudo' : '';
    return ShareTemplateSettings.interpolate(
      cfg.tournamentRankedTpl(),
      {
        'tournamentLabel': tournamentLabel,
        'rankLine': rankLine,
        'who': who,
        'signOff': signOff,
      },
    );
  }

  static String cssaFavoriteRankingShareText({
    required String clubName,
    required int rank,
    required int pts,
    required int mj,
    required int v,
    required int n,
    required int d,
    required int bf,
    required int bc,
    required String season,
    required String leagueLabel,
  }) {
    final cfg = ShareTemplatesCache.settings;
    final diff = bf - bc;
    final place = rank == 1 ? '1er' : '${rank}e';
    final diffSign = diff >= 0 ? '+' : '';
    final tpl = cfg.cssaFavoriteTpl();
    return ShareTemplateSettings.interpolate(tpl, {
      'clubName': clubName,
      'place': place,
      'pts': '$pts',
      'leagueLabel': leagueLabel,
      'season': season,
      'mj': '$mj',
      'v': '$v',
      'n': '$n',
      'd': '$d',
      'bf': '$bf',
      'bc': '$bc',
      'diffSign': diffSign,
      'diff': '$diff',
      'signOff': cfg.resolveSignOff(),
    });
  }

  static String predictionText({
    required String team1,
    required String team2,
    required int score1,
    required int score2,
    required DateTime date,
  }) {
    final cfg = ShareTemplatesCache.settings;
    final dateLabel = DateFormat('dd MMM yyyy', 'fr_FR').format(date);
    final tpl = cfg.predictionTpl();
    return ShareTemplateSettings.interpolate(tpl, {
      'team1': team1,
      'team2': team2,
      'score1': '$score1',
      'score2': '$score2',
      'dateLabel': dateLabel,
      'signOff': cfg.resolveSignOff(),
    });
  }

  static String predictionDeepLink({
    required String matchId,
    String? refUid,
  }) {
    final q = StringBuffer('dvcr://prono?matchId=$matchId');
    if (refUid != null && refUid.isNotEmpty) {
      q.write('&ref=');
      q.write(Uri.encodeComponent(refUid));
    }
    return q.toString();
  }

  static String predictionShareFullMessage({
    required String team1,
    required String team2,
    required int score1,
    required int score2,
    required DateTime date,
    required String matchId,
    String? refUid,
  }) {
    return '${predictionText(
      team1: team1,
      team2: team2,
      score1: score1,
      score2: score2,
      date: date,
    )}\n\n${predictionDeepLink(matchId: matchId, refUid: refUid)}';
  }

  static String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'fr_FR').format(date);
  }
}
