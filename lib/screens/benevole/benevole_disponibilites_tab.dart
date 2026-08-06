import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../navigation/main_shell_insets.dart';
import '../../models/benevole_availability.dart';
import '../../models/benevole_posts.dart';
import '../../services/benevole_availability_service.dart';
import '../home/home_palette.dart';

/// Onglet Disponibilités — formulaire Scénario 1 + briefs Scénario 2.
class BenevoleDisponibilitesTab extends StatelessWidget {
  const BenevoleDisponibilitesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BenevoleMatchCard>>(
      stream: BenevoleAvailabilityService.instance.watchEligibleMatches(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: homeGreen, strokeWidth: 2),
          );
        }
        final matches = snap.data ?? [];
        if (matches.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Aucun match dans la fenêtre J-20 → jour J.\n'
                'Les disponibilités s’ouvrent 20 jours avant le match '
                'et se ferment à J-6.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: homeMutedText,
                  height: 1.45,
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MainShellInsets.tabScrollTail(context, extra: 12),
          ),
          itemCount: matches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _MatchAvailabilityCard(match: matches[i]),
        );
      },
    );
  }
}

class _MatchAvailabilityCard extends StatelessWidget {
  final BenevoleMatchCard match;
  const _MatchAvailabilityCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: homeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: homeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            match.nomEvenement,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: homeText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${BenevoleAvailabilityService.formatDateFr(match.date)} · '
            '${match.benevoleType}',
            style: GoogleFonts.inter(fontSize: 12, color: homeMutedText),
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (match.lieu.isNotEmpty) match.lieu,
              if (match.ville.isNotEmpty) match.ville,
              match.domicileExterieur,
            ].where((e) => e.isNotEmpty).join(' · '),
            style: GoogleFonts.inter(fontSize: 11, color: homeMutedText),
          ),
          if (match.briefUrl != null && match.briefUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(match.briefUrl!);
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('Ouvrir le brief'),
              style: OutlinedButton.styleFrom(foregroundColor: homeGreen),
            ),
          ],
          const SizedBox(height: 10),
          StreamBuilder<BenevoleAvailabilityResponse?>(
            stream: BenevoleAvailabilityService.instance
                .watchMyResponse(match.matchId),
            builder: (context, rSnap) {
              final existing = rSnap.data;
              if (!match.formOpen) {
                return Text(
                  existing == null
                      ? 'Formulaire fermé (après J-6).'
                      : 'Ta réponse : ${existing.statutPresence}'
                          '${existing.voeu1.isNotEmpty ? ' · ${existing.voeu1}' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: homeMutedText,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (existing != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Réponse enregistrée — tu peux la modifier.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: homeGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: () => _openForm(context, match, existing),
                    style: FilledButton.styleFrom(
                      backgroundColor: homeGreen,
                      foregroundColor: homeSurface,
                    ),
                    child: Text(
                      existing == null
                          ? 'Répondre / disponibilités'
                          : 'Modifier ma réponse',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    BenevoleMatchCard match,
    BenevoleAvailabilityResponse? existing,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: homeBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AvailabilityFormSheet(
        match: match,
        existing: existing,
      ),
    );
  }
}

class _AvailabilityFormSheet extends StatefulWidget {
  final BenevoleMatchCard match;
  final BenevoleAvailabilityResponse? existing;

  const _AvailabilityFormSheet({
    required this.match,
    this.existing,
  });

  @override
  State<_AvailabilityFormSheet> createState() => _AvailabilityFormSheetState();
}

class _AvailabilityFormSheetState extends State<_AvailabilityFormSheet> {
  late String _statut;
  String? _voeu1;
  String? _voeu2;
  String? _voeu3;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _statut = e?.statutPresence ?? BenevolePresenceStatus.present;
    _voeu1 = e?.voeu1.isNotEmpty == true ? e!.voeu1 : null;
    _voeu2 = e?.voeu2.isNotEmpty == true ? e!.voeu2 : null;
    _voeu3 = e?.voeu3.isNotEmpty == true ? e!.voeu3 : null;
  }

  List<String> _optionsFor({
    required List<String> allowed,
    String? current,
    Set<String> taken = const {},
  }) {
    final base = allowed.where((p) => !taken.contains(p) || p == current);
    final list = base.toList();
    if (current != null &&
        current.isNotEmpty &&
        !list.contains(current)) {
      list.insert(0, current);
    }
    return list;
  }

  Future<void> _submit() async {
    if (_statut != BenevolePresenceStatus.absent &&
        (_voeu1 == null || _voeu1!.isEmpty)) {
      setState(() => _error = 'Choisis au moins le vœu 1 (sauf si Absent).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BenevoleAvailabilityService.instance.submit(
        matchId: widget.match.matchId,
        statutPresence: _statut,
        voeu1: _statut == BenevolePresenceStatus.absent ? '' : (_voeu1 ?? ''),
        voeu2: _statut == BenevolePresenceStatus.absent ? '' : (_voeu2 ?? ''),
        voeu3: _statut == BenevolePresenceStatus.absent ? '' : (_voeu3 ?? ''),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disponibilités envoyées', style: GoogleFonts.inter()),
          backgroundColor: homeGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MainShellInsets.sheetContentPadding(
        context,
        left: 16,
        top: 12,
        right: 16,
        extra: 16,
      ),
      child: StreamBuilder<List<String>>(
        stream: BenevoleAvailabilityService.instance.watchMyAuthorizedPosts(),
        builder: (context, postsSnap) {
          final authorized = postsSnap.data ?? const [];
          final allowed = BenevoleAvailabilityService.filterPostsForUser(
            authorized: authorized,
            benevoleType: widget.match.benevoleType,
          );
          final taken1 = <String>{
            if (_voeu2 != null && _voeu2!.isNotEmpty) _voeu2!,
            if (_voeu3 != null && _voeu3!.isNotEmpty) _voeu3!,
          };
          final taken2 = <String>{
            if (_voeu1 != null && _voeu1!.isNotEmpty) _voeu1!,
            if (_voeu3 != null && _voeu3!.isNotEmpty) _voeu3!,
          };
          final taken3 = <String>{
            if (_voeu1 != null && _voeu1!.isNotEmpty) _voeu1!,
            if (_voeu2 != null && _voeu2!.isNotEmpty) _voeu2!,
          };

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: homeBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.match.nomEvenement,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: homeText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fenêtre ouverte jusqu’à J-6 · ${widget.match.benevoleType}',
                  style: GoogleFonts.inter(fontSize: 11, color: homeMutedText),
                ),
                if (authorized.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Aucun poste autorisé sur ton profil — demande à un admin '
                    'de cocher tes postes (onglet Bénévoles).',
                    style: GoogleFonts.inter(fontSize: 11, color: homeGold),
                  ),
                ],
                const SizedBox(height: 14),
                Text('Présence', style: _labelStyle),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _statut,
                  decoration: _decoration,
                  items: BenevolePresenceStatus.all
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _statut = v);
                        },
                ),
                if (_statut != BenevolePresenceStatus.absent) ...[
                  const SizedBox(height: 12),
                  Text('Vœu 1', style: _labelStyle),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _voeu1,
                    decoration: _decoration,
                    hint: const Text('Choisir…'),
                    items: _optionsFor(
                      allowed: allowed,
                      current: _voeu1,
                      taken: taken1,
                    )
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _voeu1 = v),
                  ),
                  const SizedBox(height: 12),
                  Text('Vœu 2 (optionnel)', style: _labelStyle),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _voeu2,
                    decoration: _decoration,
                    hint: const Text('—'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('—')),
                      ..._optionsFor(
                        allowed: allowed,
                        current: _voeu2,
                        taken: taken2,
                      ).map((p) => DropdownMenuItem(value: p, child: Text(p))),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() {
                              _voeu2 = (v == null || v.isEmpty) ? null : v;
                            }),
                  ),
                  const SizedBox(height: 12),
                  Text('Vœu 3 (optionnel)', style: _labelStyle),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _voeu3,
                    decoration: _decoration,
                    hint: const Text('—'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('—')),
                      ..._optionsFor(
                        allowed: allowed,
                        current: _voeu3,
                        taken: taken3,
                      ).map((p) => DropdownMenuItem(value: p, child: Text(p))),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() {
                              _voeu3 = (v == null || v.isEmpty) ? null : v;
                            }),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(fontSize: 12, color: homeRed),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: homeGold,
                    foregroundColor: homeText,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Envoyer',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                        ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  TextStyle get _labelStyle => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: homeMutedText,
        letterSpacing: 0.4,
      );

  InputDecoration get _decoration => InputDecoration(
        filled: true,
        fillColor: homeSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: homeBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: homeBorder),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}
