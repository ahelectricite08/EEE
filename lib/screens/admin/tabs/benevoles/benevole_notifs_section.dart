import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/team_dvcr_members_service.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_shell.dart';
import '../../admin_palette.dart';
import 'benevole_notif_delivery_panel.dart';
/// Push manuelles réservées aux Team DVCR (onglet Bénévoles).
class BenevoleNotifsSection extends StatefulWidget {
  const BenevoleNotifsSection({super.key});

  @override
  State<BenevoleNotifsSection> createState() => _BenevoleNotifsSectionState();
}

class _BenevoleNotifTemplate {
  const _BenevoleNotifTemplate({
    required this.id,
    required this.label,
    required this.title,
    required this.body,
    this.icon = Icons.edit_note_rounded,
  });

  final String id;
  final String label;
  final String title;
  final String body;
  final IconData icon;
}

class _BenevoleNotifsSectionState extends State<BenevoleNotifsSection> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  /// all | ios | android
  String _targetPlatform = 'all';
  bool _testOnlyMyDevices = false;
  bool _sending = false;
  String? _lastQueueDocId;
  String _selectedTemplateId = 'blank';
  bool _sendToAllMembers = true;
  final Set<String> _selectedUids = {};
  final _memberSearchCtrl = TextEditingController();
  String _memberSearch = '';
  String _membersFingerprint = '';

  static const _maxTitle = 100;
  static const _maxBody = 360;

  static const _templates = <_BenevoleNotifTemplate>[
    _BenevoleNotifTemplate(
      id: 'blank',
      label: 'Vierge',
      title: '',
      body: '',
      icon: Icons.note_add_outlined,
    ),
    _BenevoleNotifTemplate(
      id: 'disponibilites',
      label: 'Disponibilités',
      title: 'N’oubliez pas de remplir vos disponibilités',
      body:
          'Merci de renseigner vos disponibilités pour le prochain match dans l’espace bénévoles (Profil → Bénévoles).',
      icon: Icons.event_available_rounded,
    ),
    _BenevoleNotifTemplate(
      id: 'planning',
      label: 'Planning',
      title: 'Planning bénévoles mis à jour',
      body:
          'Le planning a été mis à jour — consulte l’espace bénévoles dans l’app pour voir ton affectation.',
      icon: Icons.calendar_month_rounded,
    ),
    _BenevoleNotifTemplate(
      id: 'script',
      label: 'Script match',
      title: 'Nouveau script de match',
      body:
          'Un nouveau document est disponible dans l’espace bénévoles. Ouvre l’app : Profil → Bénévoles.',
      icon: Icons.description_rounded,
    ),
    _BenevoleNotifTemplate(
      id: 'convocation',
      label: 'Convocation',
      title: 'Convocation bénévoles — match à venir',
      body:
          'Tu es convoqué(e) pour le prochain match. Consulte le planning et le script dans l’espace bénévoles.',
      icon: Icons.campaign_rounded,
    ),
    _BenevoleNotifTemplate(
      id: 'horaire',
      label: 'Changement horaire',
      title: 'Changement d’horaire / consignes',
      body:
          'Les horaires ou consignes ont été modifiés. Vérifie le planning dans l’espace bénévoles.',
      icon: Icons.schedule_rounded,
    ),
    _BenevoleNotifTemplate(
      id: 'rappel',
      label: 'Rappel général',
      title: 'Message Team DVCR',
      body:
          'Pense à ouvrir l’espace bénévoles dans l’app pour les dernières informations.',
      icon: Icons.volunteer_activism_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() => setState(() {}));
    _bodyCtrl.addListener(() => setState(() {}));
    _applyTemplate(_templates.first);
  }

  void _applyTemplate(_BenevoleNotifTemplate template) {
    setState(() {
      _selectedTemplateId = template.id;
      _titleCtrl.text = template.title;
      _bodyCtrl.text = template.body;
      _titleCtrl.selection = TextSelection.collapsed(
        offset: _titleCtrl.text.length,
      );
      _bodyCtrl.selection = TextSelection.collapsed(
        offset: _bodyCtrl.text.length,
      );
    });
  }

  Widget _templateChip(_BenevoleNotifTemplate template) {
    final selected = _selectedTemplateId == template.id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _applyTemplate(template),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? adminGold.withAlpha(28) : adminSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? adminGold : adminBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                template.icon,
                size: 15,
                color: selected ? adminGold : adminGrey,
              ),
              const SizedBox(width: 6),
              Text(
                template.label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? adminTextPrimary : adminGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _memberSearchCtrl.dispose();
    super.dispose();
  }

  void _scheduleMembersSync(List<TeamDvcrMember> members) {
    final ids = members.map((m) => m.uid).toList()..sort();
    final fingerprint = ids.join(',');
    if (fingerprint == _membersFingerprint) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (fingerprint == _membersFingerprint) return;
      setState(() {
        _membersFingerprint = fingerprint;
        _applyMembersList(members);
      });
    });
  }

  /// Garde la sélection à jour : nouveaux Team DVCR cochés par défaut.
  void _applyMembersList(List<TeamDvcrMember> members) {
    final ids = members.map((m) => m.uid).toSet();
    if (_sendToAllMembers) {
      _selectedUids
        ..clear()
        ..addAll(ids);
      return;
    }
    final previous = Set<String>.from(_selectedUids);
    _selectedUids.removeWhere((id) => !ids.contains(id));
    for (final id in ids) {
      if (!previous.contains(id)) {
        _selectedUids.add(id);
      }
    }
  }

  List<TeamDvcrMember> _filterMembers(List<TeamDvcrMember> members) {
    final q = _memberSearch.trim().toLowerCase();
    if (q.isEmpty) return members;
    return members
        .where(
          (m) =>
              m.label.toLowerCase().contains(q) ||
              m.email.toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _recipientModeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? adminGold.withAlpha(28) : adminSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? adminGold : adminBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: selected ? adminTextPrimary : adminGrey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientsSection() {
    if (_testOnlyMyDevices) return const SizedBox.shrink();

    return StreamBuilder<List<TeamDvcrMember>>(
      stream: TeamDvcrMembersService.instance.watchMembers(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Impossible de charger les Team DVCR : ${snap.error}',
            style: GoogleFonts.inter(fontSize: 11, color: adminRed),
          );
        }
        final members = snap.data ?? [];
        if (snap.hasData) {
          _scheduleMembersSync(members);
        }

        final filtered = _filterMembers(members);
        final selectedCount =
            _sendToAllMembers ? members.length : _selectedUids.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DESTINATAIRES',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: adminGrey,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Liste synchronisée avec les comptes Team DVCR (mise à jour automatique).',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: adminGrey,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _recipientModeChip(
                  label: 'Tous (${members.length})',
                  selected: _sendToAllMembers,
                  onTap: () => setState(() => _sendToAllMembers = true),
                ),
                const SizedBox(width: 6),
                _recipientModeChip(
                  label: 'Choisir',
                  selected: !_sendToAllMembers,
                  onTap: () => setState(() {
                    _sendToAllMembers = false;
                    _applyMembersList(members);
                  }),
                ),
              ],
            ),
            if (!_sendToAllMembers) ...[
              const SizedBox(height: 10),
              Text(
                '$selectedCount sélectionné(s)',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: adminGold,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: members.isEmpty
                        ? null
                        : () => setState(() {
                            _selectedUids
                              ..clear()
                              ..addAll(members.map((m) => m.uid));
                          }),
                    child: Text(
                      'Tout cocher',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: adminGold,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: members.isEmpty
                        ? null
                        : () => setState(_selectedUids.clear),
                    child: Text(
                      'Tout décocher',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: adminGrey,
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _memberSearchCtrl,
                onChanged: (v) => setState(() => _memberSearch = v),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: adminTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Rechercher un bénévole…',
                  hintStyle: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                  isDense: true,
                  filled: true,
                  fillColor: adminSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: adminBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: adminBorder),
                  ),
                  prefixIcon: const Icon(Icons.search, size: 18, color: adminGrey),
                ),
              ),
              const SizedBox(height: 8),
              if (!snap.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: adminGold,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (members.isEmpty)
                Text(
                  'Aucun Team DVCR pour l’instant. Attribue le rôle dans Utilisateurs.',
                  style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: adminSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: adminBorder),
                  ),
                  child: SizedBox(
                    height: 200,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: adminBorder.withAlpha(120),
                      ),
                      itemBuilder: (context, i) {
                        final m = filtered[i];
                        final checked = _selectedUids.contains(m.uid);
                        return CheckboxListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          value: checked,
                          activeColor: adminGold,
                          checkColor: Colors.black,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            m.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: adminTextPrimary,
                            ),
                          ),
                          subtitle: m.email.isNotEmpty
                              ? Text(
                                  m.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: adminGrey,
                                  ),
                                )
                              : null,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedUids.add(m.uid);
                              } else {
                                _selectedUids.remove(m.uid);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  String get _platformLabel {
    switch (_targetPlatform) {
      case 'ios':
        return 'iOS uniquement';
      case 'android':
        return 'Android uniquement';
      default:
        return 'tous les appareils (iOS + Android)';
    }
  }

  bool _isBenevoleQueueDoc(Map<String, dynamic> d) {
    final audience = (d['targetAudience'] ?? 'all').toString();
    final source = (d['source'] ?? '').toString();
    return audience == 'team_dvcr' || source == 'benevole';
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    if (title.length > _maxTitle || body.length > _maxBody) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Texte trop long (titre ≤ $_maxTitle, message ≤ $_maxBody).',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_testOnlyMyDevices && (uid == null || uid.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connecte-toi avec ton compte admin pour le test.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Envoyer aux bénévoles ?',
          style: GoogleFonts.inter(
            color: adminTextPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        content: Text(
          _testOnlyMyDevices
              ? 'Test sur ton compte uniquement (aucun autre Team DVCR ne recevra la notif).'
              : _sendToAllMembers
                  ? 'Tous les Team DVCR.\nPlateforme : $_platformLabel.'
                  : '${_selectedUids.length} bénévole(s) sélectionné(s).\nPlateforme : $_platformLabel.',
          style: GoogleFonts.inter(
            color: adminGrey,
            fontSize: 12,
            height: 1.4,
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
              'ENVOYER',
              style: GoogleFonts.inter(
                color: adminGold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (!_testOnlyMyDevices &&
        !_sendToAllMembers &&
        _selectedUids.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sélectionne au moins un bénévole ou choisis « Tous ».',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final payload = <String, dynamic>{
        'title': title,
        'body': body,
        'topic': 'dvcr_alerts',
        'createdAt': FieldValue.serverTimestamp(),
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'actionType': 'none',
        'articleId': '',
        'matchId': '',
        'targetPlatform': _testOnlyMyDevices ? 'all' : _targetPlatform,
        'targetAudience': 'team_dvcr',
        'source': 'benevole',
        'createdBy': uid,
      };
      if (_testOnlyMyDevices && uid != null) {
        payload['testOnlyUid'] = uid;
      } else if (!_sendToAllMembers) {
        payload['targetUserIds'] = _selectedUids.toList();
      }
      final docRef = await FirebaseFirestore.instance
          .collection('notifications_queue')
          .add(payload);
      _titleCtrl.clear();
      _bodyCtrl.clear();
      setState(() => _lastQueueDocId = docRef.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _testOnlyMyDevices
                  ? 'Test envoyé sur ton compte.'
                  : 'Notification bénévoles mise en file — envoi en cours.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: adminGreenAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: adminRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _previewCard() {
    final title = _titleCtrl.text.trim().isEmpty
        ? 'Titre de la notification'
        : _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim().isEmpty
        ? 'Message affiché sur le téléphone.'
        : _bodyCtrl.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'APERÇU',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: adminGrey,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: adminGold.withAlpha(35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.sports_soccer_rounded,
                  color: adminGold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DVCR · Bénévoles',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: adminGrey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: adminTextPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: adminGrey,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _platformSegment(String value, String label, IconData icon) {
    final sel = _targetPlatform == value;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _testOnlyMyDevices
              ? null
              : () => setState(() => _targetPlatform = value),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: sel ? adminSurface : adminCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: sel ? adminGold.withAlpha(180) : adminBorder,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, size: 17, color: sel ? adminGold : adminGrey),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: sel ? adminTextPrimary : adminGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleLen = _titleCtrl.text.length;
    final bodyLen = _bodyCtrl.text.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminModuleSection(
          eyebrow: 'Push',
          title: 'Notifications bénévoles',
          subtitle:
              'Envoi réservé aux Team DVCR — impossible d’atteindre tous les utilisateurs depuis cet écran.',
          accent: adminGold,
          wrapInCard: false,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: adminCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: adminGold.withAlpha(80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'MODÈLES (modifiables)',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: adminGrey,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choisis un modèle puis adapte le titre et le message ci-dessous avant l’envoi.',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: adminGrey,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _templates.map(_templateChip).toList(),
                ),
                const SizedBox(height: 14),
                AdminField(
                  ctrl: _titleCtrl,
                  label: 'Titre',
                  hint: _selectedTemplateId == 'blank'
                      ? 'Écris ton titre ici…'
                      : 'Tu peux modifier le titre du modèle',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$titleLen / $_maxTitle',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: titleLen <= _maxTitle ? adminGrey : adminRed,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AdminField(
                  ctrl: _bodyCtrl,
                  label: 'Message',
                  maxLines: 4,
                  hint: _selectedTemplateId == 'blank'
                      ? 'Écris ton message ici…'
                      : 'Tu peux modifier le texte du modèle',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$bodyLen / $_maxBody',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: bodyLen <= _maxBody ? adminGrey : adminRed,
                      ),
                    ),
                  ),
                ),
                if (_titleCtrl.text.isNotEmpty || _bodyCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _previewCard(),
                ],
                const SizedBox(height: 14),
                _buildRecipientsSection(),
                const SizedBox(height: 14),
                Text(
                  'PLATEFORME',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: adminGrey,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                if (_testOnlyMyDevices)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: adminGold.withAlpha(22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: adminGold.withAlpha(90)),
                    ),
                    child: Text(
                      'Mode test : uniquement ton compte.',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: adminGold,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      _platformSegment(
                        'all',
                        'Tous',
                        Icons.devices_rounded,
                      ),
                      const SizedBox(width: 6),
                      _platformSegment(
                        'ios',
                        'iOS',
                        Icons.phone_iphone_rounded,
                      ),
                      const SizedBox(width: 6),
                      _platformSegment(
                        'android',
                        'Android',
                        Icons.android_rounded,
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _testOnlyMyDevices,
                  onChanged: (v) => setState(() => _testOnlyMyDevices = v),
                  activeThumbColor: adminGold,
                  title: Text(
                    'Test sur mon compte',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: adminTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _sending ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: adminGreen,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: adminGold.withAlpha(80),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'ENVOYER À TEAM DVCR',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        BenevoleLastSendResultPanel(queueDocId: _lastQueueDocId),
        const SizedBox(height: 14),
        AdminModuleSection(
          eyebrow: 'Historique',
          title: 'Envois récents',
          subtitle:
              'Statut par bénévole (reçu / échec / ignoré) — appuie pour le détail.',
          accent: adminGreenAccent,
          wrapInCard: false,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications_queue')
                .orderBy('sentAt', descending: true)
                .limit(40)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text(
                  'Erreur : ${snap.error}',
                  style: GoogleFonts.inter(color: adminRed, fontSize: 12),
                );
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(color: adminGold),
                  ),
                );
              }
              final docs = snap.data!.docs
                  .where((doc) => _isBenevoleQueueDoc(
                        doc.data() as Map<String, dynamic>,
                      ))
                  .take(12)
                  .toList();
              if (docs.isEmpty) {
                return Text(
                  'Aucune notification bénévole récente.',
                  style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                );
              }
              return Column(
                children: docs
                    .map(
                      (doc) => BenevoleHistoryEntry(
                        docId: doc.id,
                        data: doc.data() as Map<String, dynamic>,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
