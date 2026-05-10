import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../../../navigation/prono_championship_rollout.dart';
import '../../../../navigation/world_cup_tab_rollout.dart';
import '../../../../services/feature_flags_service.dart';

/// Affiche / masque l’onglet **PRONOS** championnat et tout l’accès prono ligue.
/// Clé Firestore : [PronoChampionshipRollout.hubFlagKey].
class PronoChampionshipHubAdminSection extends StatelessWidget {
  const PronoChampionshipHubAdminSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FeatureFlagsService.ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? const <String, dynamic>{};
        final on = data[PronoChampionshipRollout.hubFlagKey] == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRONOS CHAMPIONNAT (ROLL-OUT)',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: adminOrange,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tant que c’est OFF : pas d’onglet PRONOS en bas, pas de prono ligue '
              'depuis l’accueil / calendrier / notifs duels.',
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: adminBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PronoChampionshipRollout.hubFlagKey,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'app_config/${FeatureFlagsService.docId}',
                          style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: on,
                    onChanged: snap.hasData
                        ? (v) => FeatureFlagsService.setFlag(
                              PronoChampionshipRollout.hubFlagKey,
                              v,
                            )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Affiche / masque l’onglet **CdM 2026** dans la barre du bas et les notifs associées.
class WorldCupTabAdminSection extends StatelessWidget {
  const WorldCupTabAdminSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FeatureFlagsService.ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? const <String, dynamic>{};
        final on = !data.containsKey(WorldCupTabRollout.tabFlagKey) ||
            data[WorldCupTabRollout.tabFlagKey] == true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COUPE DU MONDE — ONGLET APP',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: adminOrange,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Par défaut (clé absente) : CdM visible. OFF explicite : pas d’onglet en bas, '
              'carte accueil masquée, raccourci profil inactif, notif points CdM bloquée.',
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: adminBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          WorldCupTabRollout.tabFlagKey,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'app_config/${FeatureFlagsService.docId}',
                          style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: on,
                    onChanged: snap.hasData
                        ? (v) => FeatureFlagsService.setFlag(
                              WorldCupTabRollout.tabFlagKey,
                              v,
                            )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bascules booléennes dans `app_config/feature_flags`.
class FeatureFlagsSection extends StatelessWidget {
  const FeatureFlagsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FeatureFlagsService.ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? const <String, dynamic>{};
        final keys = data.keys
            .where((k) => k != 'updatedAt' && data[k] is bool)
            .toList()
          ..sort();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FEATURE FLAGS',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: adminOrange,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: adminBlue.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: adminBlue.withAlpha(55)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: adminBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'C’est quoi ?',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Des interrupteurs marche / arrêt enregistrés sur le serveur. '
                          'Tu peux activer ou couper une option (carte bêta, nouvel écran, etc.) '
                          'sans republier l’app sur les stores : les téléphones récupèrent la valeur au fil du temps.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: adminGrey,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'À retenir pour le jour J',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Ici tu crées ou modifies une clé (ex. showBetaCard).\n'
                          '• Pour que ça change vraiment l’app, le code doit lire cette clé : '
                          'FeatureFlagsService.flagOn(\'ta_cle\') ou écouter '
                          'FeatureFlagsService.notifier.\n'
                          '• Tant qu’aucun écran n’utilise ta clé dans le code, '
                          'la bascule ici ne fait rien de visible — c’est normal : '
                          'l’infra est prête, le branchement se fait quand tu développes la fonction.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: adminGrey,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Document Firestore : app_config/${FeatureFlagsService.docId}',
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
            ),
            const SizedBox(height: 12),
            if (!snap.hasData && snap.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (keys.isEmpty)
              Text(
                'Aucune clé booléenne. Ajoute des champs `maFeature: true` dans la console Firebase ou ci-dessous.',
                style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              )
            else
              ...keys.map((key) {
                final on = data[key] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          key,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: adminTextPrimary,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: on,
                        onChanged: (v) =>
                            FeatureFlagsService.setFlag(key, v),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            const _AddFlagRow(),
          ],
        );
      },
    );
  }
}

class _AddFlagRow extends StatefulWidget {
  const _AddFlagRow();

  @override
  State<_AddFlagRow> createState() => _AddFlagRowState();
}

class _AddFlagRowState extends State<_AddFlagRow> {
  final _keyCtrl = TextEditingController();
  bool _on = true;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ajouter / mettre à jour une clé',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: adminGrey,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keyCtrl,
                style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
                decoration: InputDecoration(
                  hintText: 'ex. showBetaCard',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                  filled: true,
                  fillColor: adminCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: adminBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text(_on ? 'ON' : 'OFF'),
              selected: _on,
              onSelected: (v) => setState(() => _on = v),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                final k = _keyCtrl.text.trim();
                if (k.isEmpty || k == 'updatedAt') return;
                await FeatureFlagsService.setFlag(k, _on);
                _keyCtrl.clear();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Flag $k → $_on')),
                  );
                }
              },
              child: Text(
                'ENREGISTRER',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: adminOrange,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Liste `seasons` + archivage via Cloud Function [archiveCompetitionSeason].
class CompetitionSeasonsSection extends StatelessWidget {
  const CompetitionSeasonsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SAISONS (COMPÉTITIONS)',
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: adminOrange,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Collection seasons — archivage admin (Cloud Function).',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('seasons')
              .limit(50)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Text(
                'Aucune saison. Crée un document dans `seasons` (label, status, …) depuis la console ou un import.',
                style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              );
            }
            return Column(
              children: docs.map((d) {
                final m = d.data();
                final label = (m['label'] ?? d.id).toString();
                final status = (m['status'] ?? 'draft').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: adminCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: adminTextPrimary,
                              ),
                            ),
                            Text(
                              status,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (status != 'archived')
                        TextButton(
                          onPressed: () async {
                            try {
                              final callable = FirebaseFunctions.instance
                                  .httpsCallable('archiveCompetitionSeason');
                              await callable.call(<String, dynamic>{
                                'seasonId': d.id,
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Saison archivée'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                          child: Text(
                            'ARCHIVER',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              color: adminRed,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
