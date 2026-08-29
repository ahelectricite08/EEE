import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_dialogs.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import '../../../../services/seed_service.dart';
import 'adherent_vod_admin_section.dart';
import 'tv_featured_video_section.dart';
import 'tv_next_live_section.dart';
import 'tv_shorts_admin_section.dart';

/// Configuration Android TV — **`tv/config`** + pilotage direct HLS.
class TvSettingsPanel extends StatefulWidget {
  const TvSettingsPanel({super.key});

  @override
  State<TvSettingsPanel> createState() => _TvSettingsPanelState();
}

class _TvSettingsPanelState extends State<TvSettingsPanel> {
  static final _tvRef =
      FirebaseFirestore.instance.collection('tv').doc('config');
  static final _legacyRef =
      FirebaseFirestore.instance.collection('app_config').doc('tv');
  static final _liveRef =
      FirebaseFirestore.instance.collection('live').doc('current');

  final _urlCtrl = TextEditingController();
  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;
  bool _liveBusy = false;
  String? _status;
  String? _configPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      final tvSnap = await _tvRef.get();
      if (tvSnap.exists) {
        final data = tvSnap.data() ?? {};
        _urlCtrl.text = (data['streamPlaybackUrl'] ?? '').toString().trim();
        _enabled = data['enabled'] != false;
        _configPath = 'tv/config';
      } else {
        final legacy = await _legacyRef.get();
        final data = legacy.data() ?? {};
        _urlCtrl.text = (data['streamPlaybackUrl'] ?? '').toString().trim();
        _enabled = data['enabled'] != false;
        _configPath = legacy.exists ? 'app_config/tv (ancien)' : null;
      }
    } catch (e) {
      _status = 'Erreur lecture : $e';
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _status = 'URL HLS requise (ex. https://live.tondomaine.fr/live/dvcr/index.m3u8)');
      return;
    }
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      await _tvRef.set(
        {
          'streamPlaybackUrl': url,
          'enabled': _enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      try {
        await FirebaseFunctions.instance.httpsCallable('setTvStreamConfig').call({
          'streamPlaybackUrl': url,
          'enabled': _enabled,
        });
      } catch (_) {}
      if (mounted) {
        setState(() {
          _configPath = 'tv/config';
          _status =
              'Enregistré. En local : IP du PC MediaMTX ; sur VPS : URL publique HTTPS.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Erreur : $e');
      }
    }
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _startTvLive() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _status = 'Enregistre d\'abord l\'URL HLS (MediaMTX local ou VPS).');
      return;
    }
    if (!_enabled) {
      setState(() => _status = 'Active « Live TV activé » avant de lancer.');
      return;
    }

    var defaultTeam1 = 'DVCR';
    var defaultTeam2 = 'En direct';
    try {
      final tvSnap = await _tvRef.get();
      final data = tvSnap.data() ?? {};
      final t1 = (data['nextLiveTeam1'] ?? '').toString().trim();
      final t2 = (data['nextLiveTeam2'] ?? '').toString().trim();
      if (t1.isNotEmpty) defaultTeam1 = t1;
      if (t2.isNotEmpty) defaultTeam2 = t2;
    } catch (_) {}
    final team1Ctrl = TextEditingController(text: defaultTeam1);
    final team2Ctrl = TextEditingController(text: defaultTeam2);
    final ok = await adminShowFormDialog(context, 'LANCER LE DIRECT TV', [
      Text(
        'vMix envoie vers MediaMTX → cette URL HLS. '
        'L\'app télé et le badge « En direct » s\'activent.',
        style: GoogleFonts.inter(fontSize: 12, color: adminGrey, height: 1.4),
      ),
      const SizedBox(height: 12),
      AdminField(ctrl: team1Ctrl, label: 'Titre ligne 1 (ex. équipe / émission)'),
      const SizedBox(height: 8),
      AdminField(ctrl: team2Ctrl, label: 'Titre ligne 2'),
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      team1Ctrl.dispose();
      team2Ctrl.dispose();
    });
    if (!ok) return;

    setState(() => _liveBusy = true);
    try {
      await SeedService.startLive(
        url: url,
        team1: team1Ctrl.text.trim().isEmpty ? 'DVCR' : team1Ctrl.text.trim(),
        team2: team2Ctrl.text.trim().isEmpty ? 'En direct' : team2Ctrl.text.trim(),
        matchId: 'tv_${DateTime.now().millisecondsSinceEpoch}',
        streamBroadcast: true,
        tvBroadcast: true,
      );
      if (mounted) {
        setState(() => _status = 'Direct lancé — les télés DVCR voient le live.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Erreur lancement : $e');
      }
    }
    if (mounted) {
      setState(() => _liveBusy = false);
    }
  }

  Future<void> _stopTvLive() async {
    final ok = await adminConfirm(
      context,
      'Arrêter le direct ?',
    );
    if (!ok) return;
    setState(() => _liveBusy = true);
    try {
      await SeedService.clearLive();
      if (mounted) {
        setState(() => _status = 'Direct arrêté.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Erreur arrêt : $e');
      }
    }
    if (mounted) {
      setState(() => _liveBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: adminGold, strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdherentVodAdminSection(),
        const SizedBox(height: 24),
        Text(
          'FLUX HLS & DIRECT',
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: adminGold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '1) URL HLS MediaMTX (PC local puis VPS). '
          '2) Lancer / arrêter le direct ici. '
          '3) L\'app TV lit tvApi ; les vues YouTube VOD passent par le lecteur officiel.',
          style: GoogleFonts.inter(fontSize: 12, color: adminGrey, height: 1.45),
        ),
        if (_configPath != null) ...[
          const SizedBox(height: 4),
          Text(
            'Source : $_configPath',
            style: GoogleFonts.inter(fontSize: 11, color: adminOrange),
          ),
        ],
        const SizedBox(height: 14),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _liveRef.snapshots(),
          builder: (context, liveSnap) {
            final isLive = liveSnap.data?.exists == true;
            final data = liveSnap.data?.data();
            final team1 = (data?['team1'] ?? '').toString();
            final team2 = (data?['team2'] ?? '').toString();

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: adminCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLive ? adminRed.withAlpha(120) : adminBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isLive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                        color: isLive ? adminRed : adminGrey,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLive ? 'DIRECT EN COURS' : 'HORS DIRECT',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isLive ? adminRed : adminGrey,
                              ),
                            ),
                            Text(
                              isLive
                                  ? '$team1 — $team2'
                                  : 'Aucune session live/current active',
                              style: GoogleFonts.inter(fontSize: 11, color: adminGrey),
                            ),
                          ],
                        ),
                      ),
                      if (_liveBusy)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: adminGold),
                        )
                      else
                        GestureDetector(
                          onTap: isLive ? _stopTvLive : _startTvLive,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isLive ? adminRed : adminGold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isLive ? 'ARRÊTER LE DIRECT' : 'LANCER LE DIRECT',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: adminTextPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Le match calendrier (onglet Direct) utilise le même live/current. '
                    'Tu peux aussi démarrer depuis « Match en direct » avec score / buts.',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey, height: 1.35),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminField(
                ctrl: _urlCtrl,
                label: 'URL lecture HLS (index.m3u8)',
                hint: 'http://192.168.x.x:8888/live/dvcr/index.m3u8 ou https://VPS/...',
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: _saving ? null : (v) => setState(() => _enabled = v),
                title: Text(
                  'Live TV activé',
                  style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
                ),
                activeThumbColor: adminGold,
              ),
              if (_status != null) ...[
                const SizedBox(height: 8),
                Text(
                  _status!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _status!.startsWith('Erreur') ? adminRed : adminGreenAccent,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: adminGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_saving ? 'Enregistrement…' : 'Enregistrer l\'URL HLS'),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _load,
                    child: Text('Recharger', style: GoogleFonts.inter(color: adminGrey)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'PROCHAIN LIVE',
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: adminGold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        const TvNextLiveSection(),
        const SizedBox(height: 24),
        Text(
          'SHORTS YOUTUBE',
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: adminGold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        const TvShortsAdminSection(),
        const SizedBox(height: 24),
        Text(
          'VIDÉO MISE EN AVANT',
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: adminGold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        const TvFeaturedVideoSection(),
      ],
    );
  }
}
