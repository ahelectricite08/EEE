import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../services/helloasso_adhesion_service.dart';
import '../../admin_palette.dart';
import '../../admin_form_widgets.dart';
import '../../admin_module_colors.dart';
import '../../admin_module_shell.dart';
import '../../widgets/relocated_match_partner_logos_hint.dart';
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
  bool _sending = false;
  bool _sendToAllAdherents = true;
  final Set<String> _selectedUids = {};
  bool _savingExpiry = false;
  DateTime? _editingExpiry;

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
              'Date de fin d’adhésion enregistrée',
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

  Future<void> _pickExpiryDate(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      locale: const Locale('fr', 'FR'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 23,
      time?.minute ?? 59,
    );
    setState(() => _editingExpiry = combined);
    await _saveExpiry(combined);
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
              'Notification adhérents mise en file',
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
            const AdhesionBannerAdminSection(),
            const SizedBox(height: 16),
            const AdhesionSplashAdminSection(),
            const SizedBox(height: 16),
            const AdhesionStatsAdminSection(),
            const SizedBox(height: 16),
            const AdhesionWebhookAdminSection(),
            const SizedBox(height: 20),
            _expiryConfigCard(),
            const SizedBox(height: 16),
            _notificationCard(),
            const SizedBox(height: 20),
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
            );
        final display = _editingExpiry ?? cfg.adherentExpiresAt;
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
                    'Fin de statut adhérent',
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
                'Chaque paiement HelloAsso actif jusqu’au :',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
              const SizedBox(height: 10),
              Text(
                _dateFmt.format(display.toLocal()),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AdminModuleColors.communaute,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _savingExpiry
                    ? null
                    : () => _pickExpiryDate(display.toLocal()),
                icon: _savingExpiry
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_calendar_rounded, size: 16),
                label: Text(
                  'Modifier la date',
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Tous les adhérents actifs',
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
            ...docs.map((doc) {
              final d = doc.data();
              final email = (d['payerEmail'] ?? d['payerEmailLower'] ?? '')
                  .toString();
              final amount = (d['amount'] as num?)?.toDouble() ?? 0;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: adminCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: adminRed.withAlpha(100)),
                ),
                child: Text(
                  '$email — ${_moneyFmt.format(amount)} (compte introuvable)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: adminTextPrimary,
                  ),
                ),
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
  final VoidCallback onToggleSelect;
  final NumberFormat moneyFmt;
  final DateFormat dateFmt;

  const _AdherentUserTile({
    required this.uid,
    required this.payments,
    required this.selected,
    required this.selectionEnabled,
    required this.onToggleSelect,
    required this.moneyFmt,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final total = payments.fold<double>(
      0,
      (s, d) => s + ((d.data()['amount'] as num?)?.toDouble() ?? 0),
    );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        final user = userSnap.data?.data();
        final first = (user?['firstName'] ?? '').toString().trim();
        final last = (user?['lastName'] ?? '').toString().trim();
        final email = (user?['email'] ?? user?['emailLower'] ?? '').toString();
        final name = [first, last].where((s) => s.isNotEmpty).join(' ');
        final active = HelloAssoAdhesionService.isAdherentActive(user);
        final ha = user?['helloAsso'];
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
              name.isNotEmpty ? name : email,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: adminTextPrimary,
              ),
            ),
            subtitle: Text(
              '${moneyFmt.format(total)} — ${active ? 'Actif' : 'Expiré'}'
              '${expires != null ? ' · jusqu’au ${dateFmt.format(expires.toLocal())}' : ''}',
              style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
            ),
            children: payments.map((p) {
              final d = p.data();
              final amount = (d['amount'] as num?)?.toDouble() ?? 0;
              final created = d['createdAt'] ?? d['paidAt'];
              String when = '—';
              if (created is Timestamp) {
                when = dateFmt.format(created.toDate().toLocal());
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.payment_rounded,
                        size: 14, color: AdminModuleColors.communaute),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${moneyFmt.format(amount)} — $when',
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
