import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/benevole_posts.dart';
import '../../../../services/benevole_availability_service.dart';
import '../../../../services/team_dvcr_members_service.dart';
import '../../admin_palette.dart';
import '../../admin_module_colors.dart';

/// Admin — droits d’événement + postes par membre Team DVCR.
class BenevolePostesSection extends StatefulWidget {
  const BenevolePostesSection({super.key});

  @override
  State<BenevolePostesSection> createState() => _BenevolePostesSectionState();
}

class _BenevolePostesSectionState extends State<BenevolePostesSection> {
  String? _expandedUid;
  final _savingUids = <String>{};

  Future<void> _save({
    required String uid,
    required Set<String> posts,
    required Set<String> rights,
  }) async {
    setState(() => _savingUids.add(uid));
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'benevolePostes': posts.toList()..sort(),
          'benevoleEventRights': rights.toList()..sort(),
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Droits et postes enregistrés', style: GoogleFonts.inter()),
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
      if (mounted) setState(() => _savingUids.remove(uid));
    }
  }

  Future<void> _copyEmails(List<TeamDvcrMember> members) async {
    final emails = members
        .map((m) => m.email.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (emails.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aucun email Team DVCR', style: GoogleFonts.inter()),
          backgroundColor: adminRed,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: emails.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${emails.length} email(s) copié(s)',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: adminGreen.withAlpha(230),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TeamDvcrMember>>(
      stream: TeamDvcrMembersService.instance.watchMembers(),
      builder: (context, snap) {
        final members = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'DROITS + POSTES (TEAM DVCR)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AdminModuleColors.communaute,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                if (members.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _copyEmails(members),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: Text(
                      'COPIER EMAILS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Coche les types d’événements autorisés (sans le droit, '
              'la personne ne voit pas l’événement). Coupe = même droit que R1. '
              'Les vœux du formulaire sont filtrés sur les postes cochés.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: adminGrey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            if (snap.connectionState == ConnectionState.waiting &&
                members.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: adminGold),
                ),
              )
            else if (members.isEmpty)
              Text(
                'Aucun membre Team DVCR.',
                style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              )
            else
              ...members.map((m) => _MemberPostesTile(
                    member: m,
                    expanded: _expandedUid == m.uid,
                    saving: _savingUids.contains(m.uid),
                    onToggleExpand: () {
                      setState(() {
                        _expandedUid = _expandedUid == m.uid ? null : m.uid;
                      });
                    },
                    onSave: _save,
                  )),
          ],
        );
      },
    );
  }
}

class _MemberPostesTile extends StatelessWidget {
  final TeamDvcrMember member;
  final bool expanded;
  final bool saving;
  final VoidCallback onToggleExpand;
  final Future<void> Function({
    required String uid,
    required Set<String> posts,
    required Set<String> rights,
  }) onSave;

  const _MemberPostesTile({
    required this.member,
    required this.expanded,
    required this.saving,
    required this.onToggleExpand,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(member.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final rawPosts = data?['benevolePostes'];
        final currentPosts = rawPosts is List
            ? rawPosts.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet()
            : <String>{};
        final rights = BenevoleAvailabilityService.parseEventRights(data);
        final rightsMissing = rights == null;
        final currentRights = rights?.toSet() ?? BenevolePosts.allRights.toSet();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onToggleExpand,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.label,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: adminTextPrimary,
                              ),
                            ),
                            if (member.email.isNotEmpty)
                              Text(
                                member.email,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: adminGrey,
                                ),
                              ),
                            Text(
                              rightsMissing
                                  ? 'Droits : tous (non renseignés)'
                                  : 'Droits : ${currentRights.isEmpty ? 'aucun' : currentRights.map((r) => BenevolePosts.rightLabels[r] ?? r).join(', ')}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: adminGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${currentPosts.length} poste(s)',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: adminGrey,
                        ),
                      ),
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: adminGrey,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded)
                _PostesEditor(
                  uid: member.uid,
                  initialPosts: currentPosts,
                  initialRights: currentRights,
                  saving: saving,
                  onSave: onSave,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PostesEditor extends StatefulWidget {
  final String uid;
  final Set<String> initialPosts;
  final Set<String> initialRights;
  final bool saving;
  final Future<void> Function({
    required String uid,
    required Set<String> posts,
    required Set<String> rights,
  }) onSave;

  const _PostesEditor({
    required this.uid,
    required this.initialPosts,
    required this.initialRights,
    required this.saving,
    required this.onSave,
  });

  @override
  State<_PostesEditor> createState() => _PostesEditorState();
}

class _PostesEditorState extends State<_PostesEditor> {
  late Set<String> _posts;
  late Set<String> _rights;

  @override
  void initState() {
    super.initState();
    _posts = Set<String>.from(widget.initialPosts);
    _rights = Set<String>.from(widget.initialRights);
  }

  @override
  void didUpdateWidget(covariant _PostesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.saving &&
        (oldWidget.initialPosts != widget.initialPosts ||
            oldWidget.initialRights != widget.initialRights)) {
      _posts = Set<String>.from(widget.initialPosts);
      _rights = Set<String>.from(widget.initialRights);
    }
  }

  Widget _group(String title, List<String> posts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AdminModuleColors.communaute,
              letterSpacing: 0.6,
            ),
          ),
        ),
        ...posts.map(
          (poste) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              poste,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: adminTextPrimary,
              ),
            ),
            value: _posts.contains(poste),
            activeColor: AdminModuleColors.communaute,
            onChanged: widget.saving
                ? null
                : (v) {
                    setState(() {
                      if (v == true) {
                        _posts.add(poste);
                      } else {
                        _posts.remove(poste);
                      }
                    });
                  },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: adminBorder),
          const SizedBox(height: 8),
          Text(
            'TYPES D’ÉVÉNEMENTS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AdminModuleColors.communaute,
              letterSpacing: 0.6,
            ),
          ),
          ...BenevolePosts.allRights.map(
            (right) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                BenevolePosts.rightLabels[right] ?? right,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: adminTextPrimary,
                ),
              ),
              value: _rights.contains(right),
              activeColor: AdminModuleColors.communaute,
              onChanged: widget.saving
                  ? null
                  : (v) {
                      setState(() {
                        if (v == true) {
                          _rights.add(right);
                        } else {
                          _rights.remove(right);
                        }
                      });
                    },
            ),
          ),
          _group('Équipe 1ère / Coupe', BenevolePosts.premiere),
          _group('Équipe réserve', BenevolePosts.reserve),
          _group('Flammes Carolo', BenevolePosts.flammes),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: widget.saving
                ? null
                : () => widget.onSave(
                      uid: widget.uid,
                      posts: _posts,
                      rights: _rights,
                    ),
            style: FilledButton.styleFrom(
              backgroundColor: AdminModuleColors.communaute,
              foregroundColor: Colors.white,
            ),
            child: widget.saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'ENREGISTRER',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
