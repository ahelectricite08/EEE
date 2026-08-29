import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../models/adherent_vod.dart';
import '../../../../services/helloasso_adhesion_service.dart';
import '../../admin_components.dart';
import '../../admin_member_query.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../../widgets/relocated_match_partner_logos_hint.dart';
import '../settings/app_store_safe_mode_admin_section.dart';
import '../settings/soutenez_dvcr_banners_admin_section.dart';
import '../settings/support_url_admin_section.dart';
import '../staff/staff_sponsors_section.dart';
import 'adhesion_admin_sections.dart';

/// Admin — adhésion HelloAsso (bandeau, webhook, adhérents, paiements).
class AdherentsTab extends StatefulWidget {
  const AdherentsTab({super.key});

  @override
  State<AdherentsTab> createState() => _AdherentsTabState();
}

class _AdherentsTabState extends State<AdherentsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _memberSearchCtrl = TextEditingController();
  String _memberQuery = '';
  bool _sending = false;
  bool _sendToAllAdherents = true;
  String _notifSeason = '';
  final Set<String> _selectedUids = {};
  bool _savingExpiry = false;
  bool _savingCampaign = false;
  DateTime? _editingExpiry;
  DateTime? _editingCampaignEnd;

  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
  static final _moneyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _memberSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveExpiry(DateTime date) async {
    setState(() => _savingExpiry = true);
    try {
      final current = await HelloAssoAdhesionService.instance.loadConfig();
      await HelloAssoAdhesionService.instance
          .saveConfigAndRefreshActiveAdherents(
        current.copyWith(adherentExpiresAt: date),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fin de statut adhérent enregistrée (cotisation, pas la campagne)',
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
      if (mounted) setState(() => _savingExpiry = false);
    }
  }

  Future<void> _saveCampaignEnd(DateTime date) async {
    setState(() => _savingCampaign = true);
    try {
      final current = await HelloAssoAdhesionService.instance.loadConfig();
      await HelloAssoAdhesionService.instance.saveConfig(
        current.copyWith(adhesionCampaignEndsAt: date),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fin de campagne d’adhésion enregistrée',
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
      if (mounted) setState(() => _savingCampaign = false);
    }
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      locale: const Locale('fr', 'FR'),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 23,
      time?.minute ?? 59,
    );
  }

  Future<void> _pickExpiryDate(DateTime initial) async {
    final combined = await _pickDateTime(initial);
    if (combined == null) return;
    setState(() => _editingExpiry = combined);
    await _saveExpiry(combined);
  }

  Future<void> _pickCampaignEnd(DateTime initial) async {
    final combined = await _pickDateTime(initial);
    if (combined == null) return;
    setState(() => _editingCampaignEnd = combined);
    await _saveCampaignEnd(combined);
  }

  Future<void> _sendNotification() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Titre et message requis',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_sendToAllAdherents && _selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sélectionne au moins un adhérent',
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
        'targetPlatform': 'all',
        'targetAudience': 'adherent',
        'source': 'adherent_admin',
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      };
      if (_notifSeason.isNotEmpty) {
        payload['targetAdherentSeason'] = _notifSeason;
      }
      if (!_sendToAllAdherents) {
        payload['targetUserIds'] = _selectedUids.toList();
      }
      await FirebaseFirestore.instance
          .collection('notifications_queue')
          .add(payload);
      _titleCtrl.clear();
      _bodyCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notification adhérents mise en file'
                  '${_notifSeason.isEmpty ? '' : ' ($_notifSeason)'}',
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

  @override
  Widget build(BuildContext context) {
    return AdminTabPageWithSubTabs(
      title: 'HelloAsso & partenaires',
      subtitle:
          'Adhésion HelloAsso, bannières Soutenez / don, puis marque (souvenirs, sponsors).',
      icon: Icons.handshake_rounded,
      accent: AdminModuleColors.association,
      controller: _tc,
      tabs: const [
        Tab(text: 'HELLOASSO'),
        Tab(text: 'SOUTENEZ'),
        Tab(text: 'MARQUE'),
      ],
      tabViews: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          children: [
            const AppStoreSafeModeAdminSection(),
            const SizedBox(height: 16),
            const AdhesionBannerAdminSection(),
            const SizedBox(height: 16),
            const AdhesionSplashAdminSection(),
            const SizedBox(height: 16),
            _expiryConfigCard(),
            const SizedBox(height: 16),
            const AdhesionStatsAdminSection(),
            const SizedBox(height: 16),
            const AdhesionWebhookAdminSection(),
            const SizedBox(height: 20),
            _notificationCard(),
            const SizedBox(height: 20),
            AdminSearchBar(
              controller: _memberSearchCtrl,
              hint: 'Rechercher un adhérent par nom ou e-mail…',
              onChanged: (v) => setState(() => _memberQuery = v),
              onClear: () => setState(() => _memberQuery = ''),
            ),
            const SizedBox(height: 16),
            _pendingMatchesSection(),
            const SizedBox(height: 20),
            _paymentsList(),
          ],
        ),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          children: const [
            SoutenezDvcrBannersAdminSection(),
            SizedBox(height: 16),
            SupportUrlAdminSection(),
          ],
        ),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          children: const [
            RelocatedMatchPartnerLogosHint(),
            SizedBox(height: 20),
            StaffSponsorsSection(embedded: true),
          ],
        ),
      ],
    );
  }

  Widget _expiryConfigCard() {
    return StreamBuilder<HelloAssoAdhesionConfig>(
      stream: HelloAssoAdhesionService.instance.configStream(),
      builder: (context, snap) {
        final cfg = snap.data ??
            HelloAssoAdhesionConfig(
              adherentExpiresAt: _editingExpiry ??
                  HelloAssoAdhesionConfig.defaultExpiresAt,
              adhesionCampaignEndsAt: _editingCampaignEnd ??
                  HelloAssoAdhesionConfig.defaultCampaignEndsAt(),
            );
        final displayExpiry = _editingExpiry ?? cfg.adherentExpiresAt;
        final displayCampaign =
            _editingCampaignEnd ?? cfg.adhesionCampaignEndsAt;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_rounded, color: AdminModuleColors.communaute, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Deux dates distinctes',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: adminTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'La fin de campagne coupe le splash « Devenez adhérent » et '
                'bascule le bandeau accueil vers le soutien. '
                'La fin de statut adhérent gère uniquement la cotisation / VOD.',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
              ),
              const SizedBox(height: 16),
              Text(
                'Fin de campagne d’adhésion',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ex. 31 décembre minuit. Après cette date/heure, plus de splash adhésion.',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
              const SizedBox(height: 8),
              Text(
                _dateFmt.format(displayCampaign.toLocal()),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AdminModuleColors.communaute,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _savingCampaign
                    ? null
                    : () => _pickCampaignEnd(displayCampaign.toLocal()),
                icon: _savingCampaign
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_calendar_rounded, size: 16),
                label: Text(
                  'Modifier la fin de campagne',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminModuleColors.communaute,
                  side: BorderSide(color: AdminModuleColors.communaute.withAlpha(140)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Fin de statut adhérent',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: adminTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Chaque paiement HelloAsso actif jusqu’au (ex. 31 juillet) :',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
              const SizedBox(height: 8),
              Text(
                _dateFmt.format(displayExpiry.toLocal()),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AdminModuleColors.communaute,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _savingExpiry
                    ? null
                    : () => _pickExpiryDate(displayExpiry.toLocal()),
                icon: _savingExpiry
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_calendar_rounded, size: 16),
                label: Text(
                  'Modifier la fin de statut',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminModuleColors.communaute,
                  side: BorderSide(color: AdminModuleColors.communaute.withAlpha(140)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _notificationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification push aux adhérents',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: adminTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          AdminField(ctrl: _titleCtrl, label: 'Titre'),
          const SizedBox(height: 8),
          AdminField(ctrl: _bodyCtrl, label: 'Message', maxLines: 3),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey('notif-season-$_notifSeason'),
            initialValue: _notifSeason,
            decoration: InputDecoration(
              labelText: 'Saison visée',
              labelStyle: GoogleFonts.inter(fontSize: 12),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  'Tous les adhérents actifs',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
              for (final id in AdherentSeason.suggestedIds())
                DropdownMenuItem(
                  value: id,
                  child: Text(
                    'Adhérents $id',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
            ],
            onChanged: _sending
                ? null
                : (v) => setState(() => _notifSeason = v ?? ''),
          ),
          const SizedBox(height: 4),
          Text(
            _notifSeason.isEmpty
                ? 'Sans saison : uniquement les adhésions encore actives.'
                : 'Uniquement ceux qui ont cotisé $_notifSeason '
                    '(pas les autres années).',
            style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.35),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _notifSeason.isEmpty
                  ? 'Tous les adhérents actifs'
                  : 'Tous les adhérents $_notifSeason',
              style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
            ),
            value: _sendToAllAdherents,
            activeThumbColor: AdminModuleColors.communaute,
            onChanged: (v) => setState(() {
              _sendToAllAdherents = v;
              if (v) _selectedUids.clear();
            }),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _sending ? null : _sendNotification,
              style: FilledButton.styleFrom(
                backgroundColor: AdminModuleColors.communaute,
                foregroundColor: Colors.black,
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
                      'Envoyer',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingMatchesSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: HelloAssoAdhesionService.instance.pendingMatchesStream(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PAIEMENTS NON RATTACHÉS',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: adminRed,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            ...docs.where((doc) {
              final d = doc.data();
              final email = (d['payerEmail'] ?? d['payerEmailLower'] ?? '')
                  .toString();
              return adminMemberMatchesQuery(
                null,
                _memberQuery,
                extra: [email, (d['originalPayerEmail'] ?? '').toString()],
              );
            }).map((doc) {
              return _PendingHelloAssoMatchCard(
                doc: doc,
                moneyFmt: _moneyFmt,
              );
            }),
          ],
        );
      },
    );
  }

  Widget _paymentsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: HelloAssoAdhesionService.instance.donationsStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Erreur chargement : ${snap.error}',
            style: GoogleFonts.inter(color: adminRed, fontSize: 12),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AdminModuleColors.communaute),
            ),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Text(
            'Aucun paiement HelloAsso enregistré pour l’instant.',
            style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
          );
        }

        final byUser = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final doc in docs) {
          final uid = (doc.data()['userId'] ?? '').toString();
          if (uid.isEmpty) continue;
          byUser.putIfAbsent(uid, () => []).add(doc);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ADHÉRENTS & PAIEMENTS',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: adminGrey,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            ...byUser.entries.map((e) => _AdherentUserTile(
                  uid: e.key,
                  payments: e.value,
                  selected: _selectedUids.contains(e.key),
                  selectionEnabled: !_sendToAllAdherents,
                  query: _memberQuery,
                  onToggleSelect: () {
                    setState(() {
                      if (_selectedUids.contains(e.key)) {
                        _selectedUids.remove(e.key);
                      } else {
                        _selectedUids.add(e.key);
                      }
                    });
                  },
                  moneyFmt: _moneyFmt,
                  dateFmt: _dateFmt,
                )),
          ],
        );
      },
    );
  }
}

class _AdherentUserTile extends StatelessWidget {
  final String uid;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> payments;
  final bool selected;
  final bool selectionEnabled;
  final String query;
  final VoidCallback onToggleSelect;
  final NumberFormat moneyFmt;
  final DateFormat dateFmt;

  const _AdherentUserTile({
    required this.uid,
    required this.payments,
    required this.selected,
    required this.selectionEnabled,
    required this.query,
    required this.onToggleSelect,
    required this.moneyFmt,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final knownTotal = payments.fold<double>(0, (s, d) {
      final data = d.data();
      if (HelloAssoAdhesionService.isImportedAmountUnknown(data)) return s;
      return s + ((data['amount'] as num?)?.toDouble() ?? 0);
    });
    final allUnknown = payments.isNotEmpty &&
        payments.every(
          (d) => HelloAssoAdhesionService.isImportedAmountUnknown(d.data()),
        );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        final user = userSnap.data?.data();
        final payerEmails = payments.map((p) {
          final d = p.data();
          return (d['payerEmail'] ?? d['payerEmailLower'] ?? '').toString();
        });
        if (userSnap.hasData &&
            !adminMemberMatchesQuery(
              user,
              query,
              extra: [uid, ...payerEmails],
            )) {
          return const SizedBox.shrink();
        }
        final email = (user?['email'] ?? user?['emailLower'] ?? '').toString();
        final name = adminMemberDisplayName(user, fallback: email);
        final active = HelloAssoAdhesionService.isAdherentActive(user);
        final ha = user?['helloAsso'];
        final seasons = HelloAssoAdhesionService.paidSeasons(user);
        final seasonLabel = seasons.isEmpty
            ? ''
            : ' · ${([...seasons]..sort()).join(', ')}';
        DateTime? expires;
        if (ha is Map && ha['adherentExpiresAt'] is Timestamp) {
          expires = (ha['adherentExpiresAt'] as Timestamp).toDate();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? adminGreenAccent.withAlpha(120)
                  : adminBorder,
            ),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            leading: selectionEnabled
                ? Checkbox(
                    value: selected,
                    activeColor: AdminModuleColors.communaute,
                    onChanged: (_) => onToggleSelect(),
                  )
                : Icon(
                    active ? Icons.verified_rounded : Icons.history_rounded,
                    color: active ? adminGreenAccent : adminGrey,
                    size: 20,
                  ),
            title: Text(
              name.isNotEmpty ? name : (email.isNotEmpty ? email : uid),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: adminTextPrimary,
              ),
            ),
            subtitle: Text(
              '${allUnknown ? 'Import HelloAsso' : moneyFmt.format(knownTotal)}'
              ' — ${active ? 'Actif' : 'Expiré'}'
              '${expires != null ? ' · jusqu’au ${dateFmt.format(expires.toLocal())}' : ''}'
              '$seasonLabel',
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
            ),
            children: payments.map((p) {
              final d = p.data();
              final created = d['createdAt'] ?? d['paidAt'];
              String when = '—';
              if (created is Timestamp) {
                when = dateFmt.format(created.toDate().toLocal());
              }
              final amountLabel = HelloAssoAdhesionService.adhesionAmountLabel(
                d,
                formatMoney: moneyFmt.format,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.payment_rounded,
                        size: 14, color: AdminModuleColors.communaute),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$amountLabel — $when',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: adminTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _PendingHelloAssoMatchCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final NumberFormat moneyFmt;

  const _PendingHelloAssoMatchCard({
    required this.doc,
    required this.moneyFmt,
  });

  @override
  State<_PendingHelloAssoMatchCard> createState() =>
      _PendingHelloAssoMatchCardState();
}

class _PendingHelloAssoMatchCardState extends State<_PendingHelloAssoMatchCard> {
  final _emailCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _busy = true);
    try {
      final result = await HelloAssoAdhesionService.instance.linkPendingToAppEmail(
        pendingMatchId: widget.doc.id,
        appEmail: email,
      );
      if (!mounted) return;
      final linked = result['linked'] == true;
      final retargeted = result['pendingRetargeted'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            linked
                ? 'Adhésion liée au compte $email'
                : retargeted
                    ? 'Aucun compte pour $email — paiement laissé en attente sur cet e-mail'
                    : 'OK',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: adminGreenAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _emailCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Association impossible : $e'),
          backgroundColor: adminRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc.data();
    final email = (d['payerEmail'] ?? d['payerEmailLower'] ?? '').toString();
    final amountLabel = HelloAssoAdhesionService.adhesionAmountLabel(
      d,
      formatMoney: widget.moneyFmt.format,
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: adminRed.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$email — $amountLabel (compte introuvable)',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: adminTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Associer à un e-mail (celui du compte app, pas forcément HelloAsso)',
            style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _emailCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: adminTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e-mail du compte app',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                    isDense: true,
                    filled: true,
                    fillColor: adminBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: adminBorder),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Confirmer',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

