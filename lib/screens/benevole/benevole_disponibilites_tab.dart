import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/benevole_availability.dart';
import '../../navigation/main_shell_insets.dart';
import '../../services/benevole_availability_service.dart';
import '../profile/profile_palette.dart';

class BenevoleDisponibilitesTab extends StatefulWidget {
  const BenevoleDisponibilitesTab({super.key});

  @override
  State<BenevoleDisponibilitesTab> createState() =>
      _BenevoleDisponibilitesTabState();
}

class _BenevoleDisponibilitesTabState extends State<BenevoleDisponibilitesTab> {
  BenevoleAvailabilityBoard? _board;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final board = await BenevoleAvailabilityService.instance.loadBoard();
      if (!mounted) return;
      setState(() {
        _board = board;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = BenevoleAvailabilityService.friendlyError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: profileGreen, strokeWidth: 2),
      );
    }
    if (_error != null) {
      return _Message(
        text: _error!,
        action: TextButton(
          onPressed: _reload,
          child: const Text('Réessayer'),
        ),
      );
    }
    final matches = _board?.matches ?? [];
    if (matches.isEmpty) {
      return const _Message(text: 'Aucun match à venir pour les dispos.');
    }

    return RefreshIndicator(
      color: profileGreen,
      onRefresh: _reload,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MainShellInsets.tabScrollTail(context, extra: 8),
        ),
        itemCount: matches.length,
        itemBuilder: (context, i) {
          return KeyedSubtree(
            key: ValueKey(matches[i].putId),
            child: _MatchDispoCard(
              match: matches[i],
              posts: _board?.posts ?? const [],
              onSaved: _reload,
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Widget? action;

  const _Message({required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: profileMutedText,
                height: 1.45,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 10), action!],
          ],
        ),
      ),
    );
  }
}

class _MatchDispoCard extends StatefulWidget {
  final BenevoleMatchDispo match;
  final List<String> posts;
  final Future<void> Function() onSaved;

  const _MatchDispoCard({
    required this.match,
    required this.posts,
    required this.onSaved,
  });

  @override
  State<_MatchDispoCard> createState() => _MatchDispoCardState();
}

class _MatchDispoCardState extends State<_MatchDispoCard> {
  late String? _status;
  late List<String?> _wishes;
  bool _saving = false;
  bool _savedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(covariant _MatchDispoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.putId != widget.match.putId ||
        oldWidget.match.status != widget.match.status ||
        oldWidget.match.wishes.join('|') != widget.match.wishes.join('|')) {
      _hydrate();
    }
  }

  void _hydrate() {
    final incoming = widget.match.status?.toUpperCase();
    _status = incoming == BenevolePresenceStatus.absent ||
            incoming == BenevolePresenceStatus.present
        ? incoming
        : null;
    final existing = widget.match.wishes;
    _wishes = [
      existing.isNotEmpty ? existing[0] : null,
      existing.length > 1 ? existing[1] : null,
      existing.length > 2 ? existing[2] : null,
    ];
    _error = null;
  }

  String _when() {
    final d = widget.match.kickoffAt;
    if (d == null) return 'Date à confirmer';
    final local = d.toLocal();
    return DateFormat("EEEE d MMMM · HH'h'mm", 'fr_FR').format(local);
  }

  String _meta() {
    return [
      widget.match.competition,
      if (widget.match.round != null) 'J${widget.match.round}',
      widget.match.venue,
      widget.match.city,
    ].whereType<String>().where((e) => e.isNotEmpty).join(' · ');
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final status = _status;
      if (status == null) {
        setState(() {
          _error = 'Choisis Présent ou Absent.';
          _saving = false;
        });
        return;
      }
      final wishes = status == BenevolePresenceStatus.absent
          ? <String>[]
          : _wishes.whereType<String>().where((e) => e.isNotEmpty).toList();
      await BenevoleAvailabilityService.instance.submit(
        matchId: widget.match.putId,
        status: status,
        wishes: wishes,
      );
      if (!mounted) return;
      setState(() => _savedOnce = true);
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = BenevoleAvailabilityService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final present = _status == BenevolePresenceStatus.present;
    final absent = _status == BenevolePresenceStatus.absent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: profilePaper(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _when(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: profileMutedText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.match.homeTeam} – ${widget.match.awayTeam}',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: profileText,
              ),
            ),
            if (_meta().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _meta(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: profileMutedText,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ChoiceChip(
                    label: 'Présent',
                    selected: present,
                    color: profileGreen,
                    onTap: _saving
                        ? null
                        : () => setState(
                              () => _status = BenevolePresenceStatus.present,
                            ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoiceChip(
                    label: 'Absent',
                    selected: absent,
                    color: profileRed,
                    onTap: _saving
                        ? null
                        : () => setState(
                              () => _status = BenevolePresenceStatus.absent,
                            ),
                  ),
                ),
              ],
            ),
            if (present && widget.posts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Vœux de poste (3 max)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: profileText,
                ),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: widget.posts.contains(_wishes[i]) ? _wishes[i] : null,
                  isExpanded: true,
                  hint: Text(
                    '—',
                    style: GoogleFonts.inter(color: profileMutedText),
                  ),
                  decoration: InputDecoration(
                    labelText: '${i + 1}e vœu',
                    labelStyle: GoogleFonts.inter(fontSize: 12),
                    filled: true,
                    fillColor: profileSurfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: profileHairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: profileHairline),
                    ),
                  ),
                  items: widget.posts
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p,
                          child: Text(p, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _wishes[i] = v),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 12, color: profileRed),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: profileGreen,
                foregroundColor: profileSurface,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: profileSurface,
                      ),
                    )
                  : Text(
                      (widget.match.status != null || _savedOnce)
                          ? 'Modifier ma dispo'
                          : 'Envoyer ma dispo',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : profileSurfaceMuted,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? profileSurface : profileText,
            ),
          ),
        ),
      ),
    );
  }
}
