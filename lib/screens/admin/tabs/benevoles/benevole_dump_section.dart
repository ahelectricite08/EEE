import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/benevole_availability.dart';
import '../../../../services/benevole_availability_service.dart';
import '../../../../services/team_dvcr_members_service.dart';
import '../../admin_module_colors.dart';
import '../../admin_palette.dart';

/// Export bénévoles (app) pour Julien — pas de secrets Airtable.
class BenevoleDumpSection extends StatefulWidget {
  const BenevoleDumpSection({super.key});

  @override
  State<BenevoleDumpSection> createState() => _BenevoleDumpSectionState();
}

class _BenevoleDumpSectionState extends State<BenevoleDumpSection> {
  final _retrying = <String>{};

  String _csvEscape(String v) {
    final s = v.replaceAll('"', '""');
    if (s.contains(';') || s.contains('"') || s.contains('\n')) {
      return '"$s"';
    }
    return s;
  }

  Future<void> _copyRoster(List<TeamDvcrMember> members) async {
    final buf = StringBuffer(
      'nom;email;droits;postes\n',
    );
    for (final m in members) {
      // Rights/posts loaded live in the list below; roster CSV is emails+names.
      buf.writeln(
        '${_csvEscape(m.label)};${_csvEscape(m.email)};;',
      );
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Liste ${members.length} bénévole(s) copiée (nom + email). '
          'Droits/postes : copie le dump réponses ou ouvre chaque fiche.',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: adminGreen.withAlpha(230),
      ),
    );
  }

  Future<void> _copyResponses(List<BenevoleAvailabilityResponse> rows) async {
    final buf = StringBuffer(
      'date;evenement;email;statut;voeu1;voeu2;voeu3;type;makeOk\n',
    );
    for (final r in rows) {
      buf.writeln([
        r.submittedAt == null
            ? ''
            : BenevoleAvailabilityService.formatDateFr(r.submittedAt!),
        _csvEscape(r.matchId),
        _csvEscape(r.email),
        _csvEscape(r.statutPresence),
        _csvEscape(r.voeu1),
        _csvEscape(r.voeu2),
        _csvEscape(r.voeu3),
        _csvEscape(r.matchId),
        r.makeOk ? 'oui' : 'non',
      ].join(';'));
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${rows.length} réponse(s) copiée(s)',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: adminGreen.withAlpha(230),
      ),
    );
  }

  Future<void> _retry(String id) async {
    setState(() => _retrying.add(id));
    try {
      final result =
          await BenevoleAvailabilityService.instance.retryMakeSync(id);
      if (!mounted) return;
      final ok = result['makeOk'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Sync Make OK' : 'Sync Make encore en échec — voir les logs Functions',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: ok ? adminGreen.withAlpha(230) : adminRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retry : $e', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _retrying.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dump depuis Firestore (l’app). La sync planning passe par Make '
          '(secret BENEVOLE_MAKE_WEBHOOK_URL côté Functions — pas de clés '
          'Airtable dans le repo). Si Julien ne voit pas quelqu’un : '
          'vérifier makeOk = non, email manquant, ou droit/type.',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.4),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<TeamDvcrMember>>(
          stream: TeamDvcrMembersService.instance.watchMembers(),
          builder: (context, snap) {
            final members = snap.data ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '${members.length} Team DVCR',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: adminTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: members.isEmpty
                          ? null
                          : () => _copyRoster(members),
                      child: Text(
                        'COPIER NOM+EMAIL',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                ...members.take(80).map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${m.label}${m.email.isNotEmpty ? ' · ${m.email}' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: adminTextPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<BenevoleAvailabilityResponse>>(
          stream: BenevoleAvailabilityService.instance.watchAllResponses(),
          builder: (context, snap) {
            final rows = snap.data ?? [];
            final failed = rows.where((r) => !r.makeOk).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${rows.length} réponse(s) · $failed sync Make KO',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: rows.isEmpty ? null : () => _copyResponses(rows),
                      child: Text(
                        'COPIER CSV',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                ...rows.take(40).map((r) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: adminCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: r.makeOk ? adminBorder : adminRed.withAlpha(120),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.email.isEmpty ? r.uid : r.email,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: adminTextPrimary,
                                ),
                              ),
                              Text(
                                '${r.statutPresence}'
                                '${r.voeu1.isNotEmpty ? ' · ${r.voeu1}' : ''}'
                                ' · ${r.makeOk ? 'Make OK' : 'Make KO'}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: adminGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!r.makeOk)
                          TextButton(
                            onPressed: _retrying.contains(r.id)
                                ? null
                                : () => _retry(r.id),
                            child: Text(
                              'RETRY',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AdminModuleColors.communaute,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}
