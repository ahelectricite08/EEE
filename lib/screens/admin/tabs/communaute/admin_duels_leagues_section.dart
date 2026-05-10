import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/prono_social_service.dart';
import '../../admin_dialogs.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import '../../admin_stat_widgets.dart';

String _formatFirestoreTime(dynamic value) {
  if (value is Timestamp) {
    final d = value.toDate().toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  return '—';
}

/// Duels & ligues : recherche par utilisateur ou par nom de ligue, plus aperçu global réduit.
class AdminDuelsLeaguesSection extends StatefulWidget {
  const AdminDuelsLeaguesSection({super.key});

  @override
  State<AdminDuelsLeaguesSection> createState() => _AdminDuelsLeaguesSectionState();
}

class _AdminDuelsLeaguesSectionState extends State<AdminDuelsLeaguesSection> {
  final _userQueryCtrl = TextEditingController();
  final _leagueQueryCtrl = TextEditingController();
  final Set<String> _deletingLeagueIds = {};
  final Set<String> _deletingDuelIds = {};

  String? _selectedUid;
  String _selectedLabel = '';
  List<Map<String, dynamic>> _userHits = [];
  bool _userSearching = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _leagueHits = [];
  bool _leagueSearching = false;

  bool _globalExpanded = false;

  static final _uidLike = RegExp(r'^[A-Za-z0-9]{20,32}$');

  @override
  void dispose() {
    _userQueryCtrl.dispose();
    _leagueQueryCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteLeague(
    BuildContext context, {
    required String leagueId,
    required String name,
  }) async {
    final ok = await adminConfirm(
      context,
      'Supprimer la ligue « $name » ? Cette action est irréversible.',
    );
    if (!ok || !context.mounted) return;
    setState(() => _deletingLeagueIds.add(leagueId));
    try {
      await PronoSocialService.adminDeleteLeague(leagueId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ligue supprimée'),
            backgroundColor: adminGreen,
          ),
        );
      }
      setState(() {
        _leagueHits = _leagueHits.where((d) => d.id != leagueId).toList();
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: adminRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingLeagueIds.remove(leagueId));
    }
  }

  Future<void> _confirmDeleteDuel(
    BuildContext context, {
    required String duelId,
    required String label,
  }) async {
    final ok = await adminConfirm(
      context,
      'Supprimer le duel « $label » et ses pronos associés ?',
    );
    if (!ok || !context.mounted) return;
    setState(() => _deletingDuelIds.add(duelId));
    try {
      await PronoSocialService.adminDeleteDuel(duelId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Duel supprimé'),
            backgroundColor: adminGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: adminRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingDuelIds.remove(duelId));
    }
  }

  Future<void> _showDuelDetail(
    BuildContext context, {
    required String duelId,
    required Map<String, dynamic> duel,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border.all(color: adminBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  adminBottomSheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: Text(
                      'Détail duel',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: adminTextPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      children: [
                        Text(
                          'ID: $duelId',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: adminGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _kv('Statut', (duel['status'] ?? '—').toString()),
                        _kv('Match', (duel['matchLabel'] ?? '—').toString()),
                        _kv('matchId', (duel['matchId'] ?? '—').toString()),
                        _kv(
                          'Joueurs',
                          '${duel['ownerName'] ?? '?'} vs ${duel['opponentName'] ?? '?'}',
                        ),
                        _kv('ownerUid', (duel['ownerUid'] ?? '—').toString()),
                        _kv('opponentUid', (duel['opponentUid'] ?? '—').toString()),
                        _kv(
                          'Points',
                          '${duel['ownerPoints'] ?? '—'} / ${duel['opponentPoints'] ?? '—'}',
                        ),
                        _kv('Gagnant', (duel['winnerName'] ?? duel['winnerUid'] ?? '—').toString()),
                        _kv('Créé', _formatFirestoreTime(duel['createdAt'])),
                        const SizedBox(height: 16),
                        Text(
                          'Picks (sous-collection duel_picks)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('prono_duels')
                              .doc(duelId)
                              .collection('duel_picks')
                              .get(),
                          builder: (_, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            if (snap.hasError) {
                              return Text(
                                'Erreur lecture picks: ${snap.error}',
                                style: GoogleFonts.inter(fontSize: 12, color: adminRed),
                              );
                            }
                            final docs = snap.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return Text(
                                "Aucun pick enregistré (les deux joueurs n'ont peut-être pas encore saisi).",
                                style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: docs.map((d) {
                                final p = d.data();
                                final s1 = p['score1'];
                                final s2 = p['score2'];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: adminCard.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: adminBorder),
                                    ),
                                    child: Text(
                                      'UID ${d.id}  →  $s1 - $s2',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: adminTextPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              k,
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runUserSearch(BuildContext context) async {
    final q = _userQueryCtrl.text.trim();
    if (q.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisis au moins 2 caractères ou un UID complet.')),
      );
      return;
    }
    setState(() {
      _userSearching = true;
      _userHits = [];
    });
    try {
      if (_uidLike.hasMatch(q)) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(q).get();
        if (!mounted) return;
        if (doc.exists) {
          final data = doc.data();
          setState(() {
            _selectedUid = doc.id;
            _selectedLabel =
                (data?['displayName'] ?? data?['email'] ?? doc.id).toString();
            _userHits = [];
          });
          return;
        }
      }
      final hits = await PronoSocialService.searchUsers(q);
      if (!mounted) return;
      setState(() => _userHits = hits);
    } finally {
      if (mounted) setState(() => _userSearching = false);
    }
  }

  Future<void> _runLeagueNameSearch() async {
    final q = _leagueQueryCtrl.text.trim();
    if (q.length < 2) {
      setState(() => _leagueHits = []);
      return;
    }
    setState(() => _leagueSearching = true);
    try {
      final docs = await PronoSocialService.adminSearchLeaguesByName(q);
      if (!mounted) return;
      setState(() => _leagueHits = docs);
    } finally {
      if (mounted) setState(() => _leagueSearching = false);
    }
  }

  Widget _duelRow(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final id = doc.id;
    final owner = (d['ownerName'] ?? '?').toString();
    final opp = (d['opponentName'] ?? '?').toString();
    final status = (d['status'] ?? '—').toString();
    final match = (d['matchLabel'] ?? '—').toString();
    final busy = _deletingDuelIds.contains(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$owner vs $opp',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: adminTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  match,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AdminStatusChip(
                      label: status.toUpperCase(),
                      color: status == 'resolved'
                          ? adminGreen
                          : status == 'pending'
                              ? adminGold
                              : adminGrey,
                    ),
                    Text(
                      _formatFirestoreTime(d['createdAt']),
                      style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Pts ${d['ownerPoints'] ?? '—'} / ${d['opponentPoints'] ?? '—'} · Gagnant: ${d['winnerName'] ?? '—'}',
                  style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => _showDuelDetail(context, duelId: id, duel: d),
                child: Text(
                  'Détail',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: adminGold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Supprimer (admin)',
                onPressed: busy
                    ? null
                    : () => _confirmDeleteDuel(
                          context,
                          duelId: id,
                          label: '$owner vs $opp',
                        ),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.delete_outline_rounded, size: 20, color: adminRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leagueRow(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    String? highlightUid,
  }) {
    final d = doc.data();
    final id = doc.id;
    final name = (d['name'] ?? 'Ligue').toString();
    final code = (d['code'] ?? '—').toString();
    final owner = (d['ownerName'] ?? '—').toString();
    final ownerUid = (d['ownerUid'] ?? '').toString();
    final mc = d['memberCount'];
    final busy = _deletingLeagueIds.contains(id);
    final isCreator = highlightUid != null && highlightUid == ownerUid;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                    if (isCreator)
                      AdminStatusChip(label: 'CRÉATEUR', color: adminGold),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID $id · Code $code · $mc membre(s) · créateur: $owner',
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                ),
                Text(
                  'MAJ ${_formatFirestoreTime(d['updatedAt'])}',
                  style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Supprimer la ligue (admin)',
            onPressed: busy
                ? null
                : () => _confirmDeleteLeague(context, leagueId: id, name: name),
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.delete_outline_rounded, size: 22, color: adminRed),
          ),
        ],
      ),
    );
  }

  Widget _adminTextField({
    required TextEditingController ctrl,
    required String hint,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.inter(fontSize: 14, color: adminTextPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: adminGreyLight),
        filled: true,
        fillColor: adminCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: adminBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: adminBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: adminGold),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onSubmitted: onSubmitted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminSectionTitle(label: 'PRONO SOCIAL — DUELS & LIGUES'),
        const SizedBox(height: 6),
        Text(
          'Recherche ciblée (recommandé). Suppression = admin Firestore. Unicité des noms : champ nameKey (nouvelles ligues).',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
        ),
        const SizedBox(height: 14),

        Text(
          'PAR UTILISATEUR',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: adminTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _adminTextField(
                ctrl: _userQueryCtrl,
                hint: 'Nom, e-mail, ou UID Firebase…',
                onSubmitted: (_) => _runUserSearch(context),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _userSearching ? null : () => _runUserSearch(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: adminGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _userSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        'OK',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
          ],
        ),
        if (_userHits.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._userHits.map((u) {
            final uid = (u['uid'] ?? '').toString();
            final label =
                (u['displayName'] ?? u['email'] ?? uid).toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedUid = uid;
                      _selectedLabel = label;
                      _userHits = [];
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: adminBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: adminBorder),
                    ),
                    child: Text(
                      '$label · $uid',
                      style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
        if (_selectedUid != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: adminGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: adminGold.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sélection : $_selectedLabel',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: adminTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedUid!,
                        style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedUid = null;
                      _selectedLabel = '';
                    });
                  },
                  child: Text(
                    'Effacer',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ses ligues (membre)',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: adminGrey,
            ),
          ),
          const SizedBox(height: 6),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.leaguesForUser(_selectedUid!),
            builder: (_, snap) {
              if (snap.hasError) return _errorBox(snap.error.toString());
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) return _emptyHint('Aucune ligue pour cet utilisateur.');
              return Column(
                children: docs
                    .map((doc) => _leagueRow(context, doc, highlightUid: _selectedUid))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            'Ses duels',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: adminGrey,
            ),
          ),
          const SizedBox(height: 6),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: PronoSocialService.duelsForUser(_selectedUid!),
            builder: (_, snap) {
              if (snap.hasError) return _errorBox(snap.error.toString());
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) return _emptyHint('Aucun duel pour cet utilisateur.');
              return Column(
                children: docs.map((doc) => _duelRow(context, doc)).toList(),
              );
            },
          ),
        ],

        const SizedBox(height: 22),
        Text(
          'PAR NOM DE LIGUE',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: adminTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Contient le texte (sur les 400 dernières ligues mises à jour).',
          style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _adminTextField(
                ctrl: _leagueQueryCtrl,
                hint: 'Fragment du nom…',
                onSubmitted: (_) => _runLeagueNameSearch(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _leagueSearching ? null : _runLeagueNameSearch,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: adminGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _leagueSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        'OK',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
          ],
        ),
        if (_leagueHits.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._leagueHits.map((doc) => _leagueRow(context, doc)),
        ],

        const SizedBox(height: 20),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _globalExpanded,
            onExpansionChanged: (e) => setState(() => _globalExpanded = e),
            tilePadding: EdgeInsets.zero,
            title: Text(
              'APERÇU GLOBAL (50 derniers)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: adminTextPrimary,
              ),
            ),
            children: [
              Text(
                'Flux brut — utiliser la recherche ci-dessus pour le quotidien.',
                style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
              ),
              const SizedBox(height: 10),
              Text(
                'Duels',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: adminGrey,
                ),
              ),
              const SizedBox(height: 6),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: PronoSocialService.allDuelsStream(limit: 50),
                builder: (_, snap) {
                  if (snap.hasError) return _errorBox(snap.error.toString());
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) return _emptyHint('Aucun duel.');
                  return Column(children: docs.map((d) => _duelRow(context, d)).toList());
                },
              ),
              const SizedBox(height: 14),
              Text(
                'Ligues',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: adminGrey,
                ),
              ),
              const SizedBox(height: 6),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: PronoSocialService.allLeaguesStream(limit: 50),
                builder: (_, snap) {
                  if (snap.hasError) return _errorBox(snap.error.toString());
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) return _emptyHint('Aucune ligue.');
                  return Column(children: docs.map((d) => _leagueRow(context, d)).toList());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adminRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminRed.withValues(alpha: 0.35)),
      ),
      child: Text(
        msg,
        style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
      ),
    );
  }

  Widget _emptyHint(String t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Text(
        t,
        style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
      ),
    );
  }
}
