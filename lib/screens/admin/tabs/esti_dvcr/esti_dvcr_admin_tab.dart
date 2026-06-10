import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_palette.dart';
import '../../../../navigation/esti_dvcr_rollout.dart';
import '../../../../services/feature_flags_service.dart';
import '../../../../services/tournament_service.dart';
import '../tournament/tournament_tab.dart';
import '../pronos/world_cup_partner_admin_section.dart';

const _kEstiRed = Color(0xFFBA203C);

/// Onglet admin dédié ESTI'DVCR.
/// Accès : sidebar admin → ESTI'DVCR (même permission que Pronos).
class EstiDvcrAdminTab extends StatefulWidget {
  const EstiDvcrAdminTab({super.key});

  @override
  State<EstiDvcrAdminTab> createState() => _EstiDvcrAdminTabState();
}

class _EstiDvcrAdminTabState extends State<EstiDvcrAdminTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: _kEstiRed,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "ESTI'DVCR",
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: adminTextPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Tab bar ──────────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBorder),
          ),
          child: TabBar(
            controller: _tc,
            isScrollable: true,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: _kEstiRed.withAlpha(25),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _kEstiRed.withAlpha(70)),
            ),
            labelStyle:
                GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
            labelColor: _kEstiRed,
            unselectedLabelColor: adminGrey,
            tabs: const [
              Tab(text: 'MATCHS & PRONOS'),
              Tab(text: 'CLASSEMENT'),
              Tab(text: 'BANDEAU'),
              Tab(text: 'VISIBILITÉ'),
            ],
          ),
        ),

        // ── Contenu ──────────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: const [
              _MatchsPanel(),
              _ClassementPanel(),
              _BandeauPanel(),
              _VisibilitePanel(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Panel matchs ──────────────────────────────────────────────────────────────
class _MatchsPanel extends StatelessWidget {
  const _MatchsPanel();

  @override
  Widget build(BuildContext context) {
    return const TournamentTab();
  }
}

// ── Panel bandeau partenaire ──────────────────────────────────────────────────
class _BandeauPanel extends StatefulWidget {
  const _BandeauPanel();

  @override
  State<_BandeauPanel> createState() => _BandeauPanelState();
}

class _BandeauPanelState extends State<_BandeauPanel> {
  final _urlCtrl = TextEditingController();
  bool _saving = false;
  String? _savedUrl;

  static final _configRef = FirebaseFirestore.instance
      .collection('app_config')
      .doc('esti_dvcr');

  @override
  void initState() {
    super.initState();
    _configRef.get().then((snap) {
      final url = (snap.data()?['heroBannerUrl'] as String?) ?? '';
      if (mounted) {
        _urlCtrl.text = url;
        setState(() => _savedUrl = url);
      }
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _configRef.set(
      {'heroBannerUrl': _urlCtrl.text.trim()},
      SetOptions(merge: true),
    );
    if (mounted) {
      setState(() { _saving = false; _savedUrl = _urlCtrl.text.trim(); });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image de bannière enregistrée ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── Image de bannière hero ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: _kEstiRed, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text('IMAGE BANNIÈRE HERO', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: adminTextPrimary, letterSpacing: 1)),
              ]),
              const SizedBox(height: 4),
              Text(
                'URL d\'une image Wix qui remplace le fond vert/rouge du header. Laissez vide pour revenir au fond par défaut.',
                style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
              ),
              const SizedBox(height: 12),
              // Aperçu si URL définie
              if (_savedUrl != null && _savedUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _savedUrl!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      decoration: BoxDecoration(color: adminBorder, borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('Image introuvable', style: GoogleFonts.inter(fontSize: 12, color: adminGrey))),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  hintText: 'https://static.wixstatic.com/media/...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                  filled: true,
                  fillColor: adminBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: adminBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: adminBorder)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: _urlCtrl.text.isNotEmpty
                      ? IconButton(icon: Icon(Icons.clear, size: 16, color: adminGrey), onPressed: () => setState(() => _urlCtrl.clear()))
                      : null,
                ),
                style: GoogleFonts.inter(fontSize: 12),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _kEstiRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('ENREGISTRER', style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Bandeau texte au-dessus des matchs ────────────────────────────
        const WorldCupPartnerAdminSection(
          sectionTitle: "PARTENAIRE & BANDEAU ESTI'DVCR",
          buttonLabel: "ENREGISTRER ESTI'DVCR",
          bannerLabel: "Bandeau lot au-dessus des matchs",
        ),
      ],
    );
  }
}

// ── Panel classement ──────────────────────────────────────────────────────────
class _ClassementPanel extends StatefulWidget {
  const _ClassementPanel();

  @override
  State<_ClassementPanel> createState() => _ClassementPanelState();
}

const _kFinaleDay = -1;

class _ClassementPanelState extends State<_ClassementPanel> {
  int _selectedDay = 0; // 0=général, -1=phase finale, >0=journée
  List<int> _extraDays = []; // journées > 3 détectées dynamiquement

  static const _kDefaultDays = [1, 2, 3];

  @override
  void initState() {
    super.initState();
    _loadExtraDays();
  }

  Future<void> _loadExtraDays() async {
    const id = 'worldcup2026';
    final result = await TournamentService.availableMatchDaysAndPhases(id);
    if (mounted) {
      setState(() => _extraDays = result.days.where((d) => d > 3).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    const id = 'worldcup2026';

    final allDays = [..._kDefaultDays, ..._extraDays];
    final chips = <({int day, String label})>[
      (day: 0, label: 'GÉNÉRAL'),
      for (final d in allDays) (day: d, label: 'J$d'),
      (day: _kFinaleDay, label: 'PHASE FINALE'),
    ];

    Stream<List<TournamentEntry>> stream;
    if (_selectedDay == 0) {
      stream = TournamentService.leaderboardTopStream(id, limit: 100);
    } else if (_selectedDay == _kFinaleDay) {
      stream = TournamentService.leaderboardFinaleStream(id);
    } else {
      stream = TournamentService.leaderboardByMatchDayStream(id, _selectedDay);
    }

    return Column(
      children: [
        // Sélecteur journée
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final chip = chips[i];
              final sel = _selectedDay == chip.day;
              final isFinale = chip.day == _kFinaleDay;
              final activeColor = isFinale ? adminGold : _kEstiRed;
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = chip.day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: sel ? activeColor.withAlpha(20) : adminCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel
                          ? activeColor.withAlpha(100)
                          : isFinale
                              ? adminGold.withAlpha(60)
                              : adminBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      chip.label,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: sel
                            ? activeColor
                            : isFinale
                                ? adminGold
                                : adminGrey,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Liste
        Expanded(child: _AdminLeaderboardList(stream: stream)),
      ],
    );
  }
}

class _AdminLeaderboardList extends StatelessWidget {
  final Stream<List<TournamentEntry>> stream;
  const _AdminLeaderboardList({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TournamentEntry>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: adminGold));
        }
        final entries = snap.data!;
        if (entries.isEmpty) {
          return Center(
            child: Text('Aucun participant', style: GoogleFonts.inter(color: adminGrey)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final e = entries[i];
            final rank = i + 1;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: adminBorder),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: adminGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: adminTextPrimary,
                          ),
                        ),
                        if (e.exactScores > 0)
                          Text(
                            '${e.exactScores} score${e.exactScores > 1 ? 's' : ''} exact${e.exactScores > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(fontSize: 10, color: adminGold),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: adminGold.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: adminGold.withAlpha(60)),
                    ),
                    child: Text(
                      '${e.points} pts',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: adminGold,
                      ),
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
}

// ── Panel visibilité ──────────────────────────────────────────────────────────
class _VisibilitePanel extends StatelessWidget {
  const _VisibilitePanel();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FeatureFlagsService.ref.snapshots(),
          builder: (context, snap) {
            final isVisible = EstiDvcrRollout.isTabVisible;
            return Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isVisible ? _kEstiRed.withAlpha(80) : adminBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _kEstiRed,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Onglet ESTI'DVCR dans l'app",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: adminTextPrimary,
                          ),
                        ),
                      ),
                      Switch(
                        value: isVisible,
                        activeThumbColor: _kEstiRed,
                        onChanged: snap.hasData
                            ? (v) => FeatureFlagsService.setFlag(
                                  EstiDvcrRollout.tabFlagKey,
                                  v,
                                )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Active ou désactive l\'onglet Esti\'DVCR dans l\'app mobile. '
                    'Les pronos et classements sont conservés même quand l\'onglet est masqué.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: adminBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: adminBorder),
                    ),
                    child: Text(
                      EstiDvcrRollout.tabFlagKey,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: adminGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
