import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import '../../../../services/app_settings_service.dart';
import '../../../../services/dvcr_share_service.dart';
import '../../../../utils/share_template_settings.dart';

/// Édition des textes de partage (`app_config/share_text_templates`).
class ShareTextTemplatesSection extends StatefulWidget {
  const ShareTextTemplatesSection({super.key});

  @override
  State<ShareTextTemplatesSection> createState() =>
      _ShareTextTemplatesSectionState();
}

class _KeyValCtrls {
  _KeyValCtrls(String k, String v)
      : key = TextEditingController(text: k),
        val = TextEditingController(text: v);

  final TextEditingController key;
  final TextEditingController val;

  void dispose() {
    key.dispose();
    val.dispose();
  }
}

class _ShareTextTemplatesSectionState extends State<ShareTextTemplatesSection> {
  final _signOffCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();
  final _articleDefaultCtrl = TextEditingController();
  final _videoDefaultCtrl = TextEditingController();
  final _matchFinishedScoredCtrl = TextEditingController();
  final _matchFinishedNoScoreCtrl = TextEditingController();
  final _matchLiveCtrl = TextEditingController();
  final _matchUpcomingCtrl = TextEditingController();
  final _replayStripCtrl = TextEditingController();
  final _tournamentEmptyCtrl = TextEditingController();
  final _tournamentRankedCtrl = TextEditingController();
  final _cssaFavoriteCtrl = TextEditingController();
  final _predictionCtrl = TextEditingController();
  final _matchHeaderCtrl = TextEditingController();
  final _matchOutroSedanCtrl = TextEditingController();
  final _matchOutroDefaultCtrl = TextEditingController();
  final _tournamentExactOneCtrl = TextEditingController();
  final _tournamentExactManyCtrl = TextEditingController();
  final _tournamentLeaderCtrl = TextEditingController();
  final _tournamentRankCtrl = TextEditingController();
  final _tournamentGenericCtrl = TextEditingController();

  final List<_KeyValCtrls> _articleCats = [];
  final List<_KeyValCtrls> _videoCats = [];

  bool _loading = true;
  bool _saving = false;
  StreamSubscription<ShareTemplateSettings>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AppSettingsService.shareTemplatesStream().listen(_applyRemote);
  }

  void _applyRemote(ShareTemplateSettings s) {
    if (!mounted) return;
    void setIf(TextEditingController c, String v) {
      if (c.text != v) c.text = v;
    }

    setIf(_signOffCtrl, s.signOffBody);
    setIf(_siteCtrl, s.siteUrl);
    setIf(_articleDefaultCtrl, s.articleDefault);
    setIf(_videoDefaultCtrl, s.videoDefault);
    setIf(_matchFinishedScoredCtrl, s.matchFinishedScored);
    setIf(_matchFinishedNoScoreCtrl, s.matchFinishedNoScore);
    setIf(_matchLiveCtrl, s.matchLive);
    setIf(_matchUpcomingCtrl, s.matchUpcoming);
    setIf(_replayStripCtrl, s.replayStrip);
    setIf(_tournamentEmptyCtrl, s.tournamentEmpty);
    setIf(_tournamentRankedCtrl, s.tournamentRanked);
    setIf(_cssaFavoriteCtrl, s.cssaFavoriteRanking);
    setIf(_predictionCtrl, s.prediction);
    setIf(_matchHeaderCtrl, s.matchScoredHeader);
    setIf(_matchOutroSedanCtrl, s.matchOutroSedan);
    setIf(_matchOutroDefaultCtrl, s.matchOutroDefault);
    setIf(_tournamentExactOneCtrl, s.tournamentExactOne);
    setIf(_tournamentExactManyCtrl, s.tournamentExactMany);
    setIf(_tournamentLeaderCtrl, s.tournamentLeaderLine);
    setIf(_tournamentRankCtrl, s.tournamentRankLine);
    setIf(_tournamentGenericCtrl, s.tournamentGenericLine);

    _syncMapRows(_articleCats, s.articleByCategory);
    _syncMapRows(_videoCats, s.videoByCategory);

    setState(() => _loading = false);
  }

  void _syncMapRows(List<_KeyValCtrls> rows, Map<String, String> map) {
    if (rows.isEmpty && map.isEmpty) return;
    final sameLength = rows.length == map.length;
    if (sameLength) {
      var i = 0;
      var ok = true;
      for (final e in map.entries) {
        if (rows[i].key.text != e.key || rows[i].val.text != e.value) {
          ok = false;
          break;
        }
        i++;
      }
      if (ok) return;
    }
    for (final r in rows) {
      r.dispose();
    }
    rows.clear();
    for (final e in map.entries) {
      rows.add(_KeyValCtrls(e.key, e.value));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _signOffCtrl.dispose();
    _siteCtrl.dispose();
    _articleDefaultCtrl.dispose();
    _videoDefaultCtrl.dispose();
    _matchFinishedScoredCtrl.dispose();
    _matchFinishedNoScoreCtrl.dispose();
    _matchLiveCtrl.dispose();
    _matchUpcomingCtrl.dispose();
    _replayStripCtrl.dispose();
    _tournamentEmptyCtrl.dispose();
    _tournamentRankedCtrl.dispose();
    _predictionCtrl.dispose();
    _cssaFavoriteCtrl.dispose();
    _matchHeaderCtrl.dispose();
    _matchOutroSedanCtrl.dispose();
    _matchOutroDefaultCtrl.dispose();
    _tournamentExactOneCtrl.dispose();
    _tournamentExactManyCtrl.dispose();
    _tournamentLeaderCtrl.dispose();
    _tournamentRankCtrl.dispose();
    _tournamentGenericCtrl.dispose();
    for (final r in _articleCats) {
      r.dispose();
    }
    for (final r in _videoCats) {
      r.dispose();
    }
    super.dispose();
  }

  Map<String, String> _collectMap(List<_KeyValCtrls> rows) {
    final out = <String, String>{};
    for (final r in rows) {
      final k = r.key.text.trim();
      if (k.isEmpty) continue;
      out[k] = r.val.text;
    }
    return out;
  }

  ShareTemplateSettings _collectSettings() {
    return ShareTemplateSettings(
      signOffBody: _signOffCtrl.text,
      siteUrl: _siteCtrl.text.trim(),
      articleDefault: _articleDefaultCtrl.text,
      articleByCategory: _collectMap(_articleCats),
      videoDefault: _videoDefaultCtrl.text,
      videoByCategory: _collectMap(_videoCats),
      matchFinishedScored: _matchFinishedScoredCtrl.text,
      matchFinishedNoScore: _matchFinishedNoScoreCtrl.text,
      matchLive: _matchLiveCtrl.text,
      matchUpcoming: _matchUpcomingCtrl.text,
      replayStrip: _replayStripCtrl.text,
      tournamentEmpty: _tournamentEmptyCtrl.text,
      tournamentRanked: _tournamentRankedCtrl.text,
      cssaFavoriteRanking: _cssaFavoriteCtrl.text,
      prediction: _predictionCtrl.text,
      matchScoredHeader: _matchHeaderCtrl.text,
      matchOutroSedan: _matchOutroSedanCtrl.text,
      matchOutroDefault: _matchOutroDefaultCtrl.text,
      tournamentExactOne: _tournamentExactOneCtrl.text,
      tournamentExactMany: _tournamentExactManyCtrl.text,
      tournamentLeaderLine: _tournamentLeaderCtrl.text,
      tournamentRankLine: _tournamentRankCtrl.text,
      tournamentGenericLine: _tournamentGenericCtrl.text,
    );
  }

  void _fillBuiltInTemplates() {
    _signOffCtrl.clear();
    _siteCtrl.clear();
    _articleDefaultCtrl.clear();
    _videoDefaultCtrl.clear();
    for (final r in _articleCats) {
      r.dispose();
    }
    for (final r in _videoCats) {
      r.dispose();
    }
    _articleCats.clear();
    _videoCats.clear();

    _matchFinishedScoredCtrl.text = kDefaultMatchFinishedScored;
    _matchFinishedNoScoreCtrl.text = kDefaultMatchFinishedNoScore;
    _matchLiveCtrl.text = kDefaultMatchLive;
    _matchUpcomingCtrl.text = kDefaultMatchUpcoming;
    _replayStripCtrl.text = kDefaultReplayStrip;
    _tournamentEmptyCtrl.text = kDefaultTournamentEmpty;
    _tournamentRankedCtrl.text = kDefaultTournamentRanked;
    _cssaFavoriteCtrl.text = kDefaultCssaFavorite;
    _predictionCtrl.text = kDefaultPrediction;
    _articleDefaultCtrl.text = kDefaultArticleTemplate;
    _videoDefaultCtrl.text = kDefaultVideoTemplate;
    _matchHeaderCtrl.text = kDefaultMatchScoredHeader;
    _matchOutroSedanCtrl.text = kDefaultMatchOutroSedan;
    _matchOutroDefaultCtrl.text = kDefaultMatchOutroDefault;
    _tournamentExactOneCtrl.text = kDefaultTournamentExactOne;
    _tournamentExactManyCtrl.text = kDefaultTournamentExactMany;
    _tournamentLeaderCtrl.text = kDefaultTournamentLeaderLine;
    _tournamentRankCtrl.text = kDefaultTournamentRankLine;
    _tournamentGenericCtrl.text = kDefaultTournamentGenericLine;
    setState(() {});
  }

  Widget _legend() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: adminBlue.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: adminBlue.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Placeholders (taper exactement {{nom}}) :',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: adminTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Communs : {{signOff}} (signature ; laisser « Signature DVCR » vide = texte intégré), '
            '{{siteUrl}} n’existe pas — utilise l’URL dans le champ Site.\n\n'
            'Actu : {{emoji}} {{title}} {{category}} {{date}} {{excerpt}}\n'
            'Vidéo : {{emoji}} {{title}} {{meta}}\n'
            'Match score : {{header}} {{team1}} {{team2}} {{s1}} {{s2}} {{when}} {{compLine}} {{outro}}\n'
            'Match sans score : {{team1}} {{team2}} {{when}} {{compLine}}\n'
            'Live : {{team1}} {{team2}} {{scoreLine}} {{when}} {{compLine}}\n'
            'À venir : {{team1}} {{team2}} {{when}} {{compLine}}\n'
            'Replay liste : {{emoji}} {{title}} {{duration}} {{relativeDate}}\n'
            'Prono classement vide : {{tournamentLabel}}\n'
            'Prono classement : {{tournamentLabel}} {{rankLine}} {{who}}\n'
            'Classement club : {{clubName}} {{place}} {{pts}} {{leagueLabel}} {{season}} '
            '{{mj}} {{v}} {{n}} {{d}} {{bf}} {{bc}} {{diffSign}} {{diff}}\n'
            'Prono match : {{team1}} {{team2}} {{score1}} {{score2}} {{dateLabel}}\n\n'
            'Phrases auto (classement prono) : {{pts}} {{rank}} {{exactLine}} {{count}}\n'
            'Match Sedan/CSSA : outro club · autres matchs : outro défaut',
            style: GoogleFonts.inter(fontSize: 9.5, color: adminGrey, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _catBlock({
    required String title,
    required List<_KeyValCtrls> rows,
    required VoidCallback onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: adminTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...rows.asMap().entries.map((e) {
          final r = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: AdminField(
                    ctrl: r.key,
                    label: 'Catégorie',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdminField(
                    ctrl: r.val,
                    label: 'Modèle (prioritaire sur le défaut)',
                    maxLines: 5,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      r.dispose();
                      rows.removeAt(e.key);
                    });
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: adminGrey,
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text('Ajouter une catégorie', style: GoogleFonts.inter(fontSize: 11)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ShareTemplatesAdminCard(
      title: 'TEXTES DE PARTAGE (TOUS LES MESSAGES)',
      icon: Icons.message_outlined,
      color: adminPurple,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: adminGold,
                  strokeWidth: 2,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legend(),
                  Text(
                    'Champs vides côté modèle global = texte intégré d’origine dans l’app. '
                    'Les lignes « par catégorie » remplacent le modèle actu/vidéo si la catégorie '
                    'de l’article ou de la vidéo correspond (insensible à la casse).',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  AdminField(
                    ctrl: _signOffCtrl,
                    label: 'Signature DVCR (optionnel, remplace tout le bloc {{signOff}})',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _siteCtrl,
                    label: 'URL site dans la signature par défaut (ex. https://www.dvcr.fr)',
                  ),
                  const SizedBox(height: 16),
                  AdminField(
                    ctrl: _articleDefaultCtrl,
                    label: 'Modèle partage ACTU (défaut toutes catégories)',
                    maxLines: 8,
                  ),
                  const SizedBox(height: 12),
                  _catBlock(
                    title: 'Actus — surcharges par catégorie',
                    rows: _articleCats,
                    onAdd: () => setState(() => _articleCats.add(_KeyValCtrls('', ''))),
                  ),
                  const SizedBox(height: 16),
                  AdminField(
                    ctrl: _videoDefaultCtrl,
                    label: 'Modèle partage VIDÉO / replay (défaut)',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 12),
                  _catBlock(
                    title: 'Vidéos — surcharges par catégorie',
                    rows: _videoCats,
                    onAdd: () => setState(() => _videoCats.add(_KeyValCtrls('', ''))),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Matchs',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: adminOrange,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _matchHeaderCtrl,
                    label: 'Titre match terminé (→ {{header}})',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _matchOutroSedanCtrl,
                    label: 'Outro match Sedan / CSSA (→ {{outro}})',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _matchOutroDefaultCtrl,
                    label: 'Outro autres matchs (→ {{outro}})',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _matchFinishedScoredCtrl,
                    label: 'Modèle match terminé (avec score)',
                    maxLines: 8,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _matchFinishedNoScoreCtrl,
                    label: 'Modèle match terminé (sans score)',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _matchLiveCtrl,
                    label: 'Modèle match en direct',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _matchUpcomingCtrl,
                    label: 'Modèle match à venir',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Vidéo replay · Pronos · Classements',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: adminOrange,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _replayStripCtrl,
                    label: 'Replay (liste compacte)',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _tournamentEmptyCtrl,
                    label: 'Classement prono (profil vide)',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _tournamentLeaderCtrl,
                    label: 'Ligne classement — 1er ({{pts}} {{exactLine}})',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _tournamentRankCtrl,
                    label: 'Ligne classement — Xe ({{rank}} {{pts}} {{exactLine}})',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _tournamentGenericCtrl,
                    label: 'Ligne classement — sans rang ({{pts}} {{exactLine}})',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _tournamentExactOneCtrl,
                    label: 'Suffixe 1 score exact ({{exactLine}})',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _tournamentExactManyCtrl,
                    label: 'Suffixe N scores exacts ({{count}})',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _tournamentRankedCtrl,
                    label: 'Modèle classement prono (avec {{rankLine}} {{who}})',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _cssaFavoriteCtrl,
                    label: 'Classement club favori (CSSA…)',
                    maxLines: 8,
                  ),
                  const SizedBox(height: 10),
                  AdminField(
                    ctrl: _predictionCtrl,
                    label: 'Partage prono score (sans lien profond)',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _fillBuiltInTemplates,
                        child: Text(
                          'Remplir avec les modèles intégrés',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              await AppSettingsService.saveShareTemplates(
                                _collectSettings(),
                              );
                              DvcrShare.clearSettingsCache();
                              if (mounted) setState(() => _saving = false);
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: adminGold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'ENREGISTRER',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ShareTemplatesAdminCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _ShareTemplatesAdminCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: adminTextPrimary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: adminBorder),
          ),
          child: child,
        ),
      ],
    );
  }
}
