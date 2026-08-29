import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../models/benevole_availability.dart';
import '../../../../models/benevole_posts.dart';
import '../../../../services/benevole_availability_service.dart';
import '../../admin_dialogs.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_colors.dart';
import '../../admin_palette.dart';

/// Création d’événements perso + matchs réserve (calendrier).
class BenevoleEventsSection extends StatefulWidget {
  const BenevoleEventsSection({super.key});

  @override
  State<BenevoleEventsSection> createState() => _BenevoleEventsSectionState();
}

class _BenevoleEventsSectionState extends State<BenevoleEventsSection> {
  bool _busy = false;

  Future<void> _pickDateTime({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 400)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    onPicked(DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  Future<void> _createPerso() async {
    final titleCtrl = TextEditingController();
    final lieuCtrl = TextEditingController();
    final villeCtrl = TextEditingController();
    var date = DateTime.now().add(const Duration(days: 10));
    date = DateTime(date.year, date.month, date.day, 18);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: adminCard,
          title: Text(
            'Intervention extérieure',
            style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hors calendrier football. Postes = liste équipe 1ère '
                  '(caméra / régie). Visible seulement des bénévoles '
                  'avec le droit Perso / extérieur, de J-20 à J-3 12h.',
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.4),
                ),
                const SizedBox(height: 10),
                AdminField(ctrl: titleCtrl, label: 'Titre'),
                const SizedBox(height: 8),
                AdminField(ctrl: lieuCtrl, label: 'Lieu'),
                const SizedBox(height: 8),
                AdminField(ctrl: villeCtrl, label: 'Ville'),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(date),
                    style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
                  ),
                  trailing: Text(
                    'DATE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AdminModuleColors.communaute,
                    ),
                  ),
                  onTap: () => _pickDateTime(
                    initial: date,
                    onPicked: (d) => setLocal(() => date = d),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'CRÉER',
                style: GoogleFonts.inter(
                  color: adminGold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Titre requis', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await BenevoleAvailabilityService.instance.createCustomEvent(
        title: titleCtrl.text.trim(),
        date: date,
        lieu: lieuCtrl.text.trim(),
        ville: villeCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Événement perso créé', style: GoogleFonts.inter()),
          backgroundColor: adminGreen.withAlpha(230),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createReserve() async {
    final oppCtrl = TextEditingController();
    final lieuCtrl = TextEditingController(text: 'Stade Louis Dugauguez');
    final villeCtrl = TextEditingController(text: 'Sedan');
    var date = DateTime.now().add(const Duration(days: 10));
    date = DateTime(date.year, date.month, date.day, 15);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: adminCard,
          title: Text(
            'Match équipe réserve',
            style: GoogleFonts.inter(color: adminTextPrimary, fontSize: 14),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ajoute le match au calendrier app (la synchro FFF ne '
                  'couvre que l’équipe 1ère R1). Formulaire bénévoles : '
                  'postes Réserve, droit Réserve.',
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.4),
                ),
                const SizedBox(height: 10),
                AdminField(ctrl: oppCtrl, label: 'Adversaire'),
                const SizedBox(height: 8),
                AdminField(ctrl: lieuCtrl, label: 'Lieu'),
                const SizedBox(height: 8),
                AdminField(ctrl: villeCtrl, label: 'Ville'),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(date),
                    style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
                  ),
                  trailing: Text(
                    'DATE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AdminModuleColors.communaute,
                    ),
                  ),
                  onTap: () => _pickDateTime(
                    initial: date,
                    onPicked: (d) => setLocal(() => date = d),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('ANNULER', style: GoogleFonts.inter(color: adminGrey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'CRÉER',
                style: GoogleFonts.inter(
                  color: adminGold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (oppCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Adversaire requis', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await BenevoleAvailabilityService.instance.createReserveMatch(
        opponent: oppCtrl.text.trim(),
        date: date,
        lieu: lieuCtrl.text.trim(),
        ville: villeCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Match réserve ajouté au calendrier',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: adminGreen.withAlpha(230),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'La synchro FFF n’importe que l’équipe 1ère (R1). Pour la réserve, '
          'crée le match ici — il apparaît dans le calendrier app et ouvre '
          'le formulaire bénévoles J-20 → J-3 12h. '
          'Flammes : même principe via Matchs → type Flammes, ou une fiche manuelle.',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.4),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _createPerso,
                style: FilledButton.styleFrom(
                  backgroundColor: AdminModuleColors.communaute,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'ÉVÉNEMENT PERSO',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _createReserve,
                child: Text(
                  'MATCH RÉSERVE',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<BenevoleMatchCard>>(
          stream: BenevoleAvailabilityService.instance.watchUpcomingCustomEvents(),
          builder: (context, snap) {
            final events = snap.data ?? [];
            if (events.isEmpty) {
              return Text(
                'Aucun événement perso à venir.',
                style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              );
            }
            return Column(
              children: events.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: adminCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: adminBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.nomEvenement,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: adminTextPrimary,
                              ),
                            ),
                            Text(
                              '${BenevoleAvailabilityService.formatDateFr(e.date)}'
                              '${e.lieu.isNotEmpty ? ' · ${e.lieu}' : ''}'
                              '${e.ville.isNotEmpty ? ' · ${e.ville}' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: adminRed,
                          size: 20,
                        ),
                        onPressed: _busy
                            ? null
                            : () async {
                                final confirm = await adminConfirm(
                                  context,
                                  'Supprimer « ${e.nomEvenement} » ?',
                                );
                                if (confirm == true) {
                                  await BenevoleAvailabilityService.instance
                                      .deleteCustomEvent(e.matchId);
                                }
                              },
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
